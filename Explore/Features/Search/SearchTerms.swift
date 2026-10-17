import SwiftUI

/// The words a search looks for and where they show in a result, matched
/// the way the server matches them (internal/store/search.go in the
/// explore repo, web/src/lib/highlight.ts on the website): Chinese as
/// typed, other words whole.
nonisolated enum SearchTerms {
    static let maxWords = 8

    /// Scripts written without spaces between words; the server's CJK ranges.
    private static let cjkRanges: [ClosedRange<UInt32>] = [
        0x3040...0x30FF, 0x3400...0x4DBF, 0x4E00...0x9FFF,
        0xAC00...0xD7AF, 0xF900...0xFAFF, 0x20000...0x3134F,
    ]

    static func isCJK(_ character: Character) -> Bool {
        guard let scalar = character.unicodeScalars.first else { return false }
        return cjkRanges.contains { $0.contains(scalar.value) }
    }

    /// A letter or digit outside CJK, which may not touch a whole word.
    private static func joinsWord(_ character: Character) -> Bool {
        (character.isLetter || character.isNumber) && !isCJK(character)
    }

    /// Splits a query into its words: at spaces, and at punctuation standing
    /// alone between them, as in "你好，世界".
    static func words(in query: String) -> [String] {
        var words: [String] = []
        for field in query.lowercased().split(whereSeparator: \.isWhitespace) {
            var word = ""
            var run = ""
            func flush() {
                if let first = run.first, !isCJK(first), !run.contains(where: { $0.isLetter || $0.isNumber }) {
                    if !word.isEmpty { words.append(word) }
                    word = ""
                } else {
                    word += run
                }
                run = ""
            }
            for character in field {
                if let first = run.first, isCJK(character) != isCJK(first) { flush() }
                run.append(character)
            }
            flush()
            if !word.isEmpty { words.append(word) }
        }
        return Array(words.prefix(maxWords))
    }

    /// Where the words show in a text, in order and never overlapping;
    /// longer words win over the shorter ones inside them.
    static func ranges(of words: [String], in text: String) -> [Range<String.Index>] {
        let unique = Set(words.filter { !$0.isEmpty }).sorted { ($0.count, $1) > ($1.count, $0) }
        var found: [Range<String.Index>] = []
        for word in unique {
            let wholeStart = !isCJK(word.first!)
            let wholeEnd = !isCJK(word.last!)
            var from = text.startIndex
            while from < text.endIndex,
                  let match = text.range(of: word, options: .caseInsensitive, range: from..<text.endIndex) {
                let touches = (wholeStart && match.lowerBound > text.startIndex && joinsWord(text[text.index(before: match.lowerBound)]))
                    || (wholeEnd && match.upperBound < text.endIndex && joinsWord(text[match.upperBound]))
                if touches || found.contains(where: { $0.overlaps(match) }) {
                    from = text.index(after: match.lowerBound)
                } else {
                    found.append(match)
                    from = match.upperBound
                }
            }
        }
        return found.sorted { $0.lowerBound < $1.lowerBound }
    }

    /// The text from shortly before its first word when that word would
    /// sit past what two lines show, so a match in an excerpt stays in view.
    static func snippet(_ text: String, words: [String], lead: Int = 30) -> String {
        guard let first = ranges(of: words, in: text).first,
              text.distance(from: text.startIndex, to: first.lowerBound) > lead else { return text }
        var start = text.index(first.lowerBound, offsetBy: -12)
        // Start at a word in scripts with spaces, not halfway through one.
        if let space = text[start..<first.lowerBound].firstIndex(where: \.isWhitespace) {
            start = text.index(after: space)
        }
        return "…" + text[start...].trimmingCharacters(in: .whitespaces)
    }

    /// The text with the words marked, as the website marks them.
    static func marked(_ text: String, words: [String]) -> AttributedString {
        var marked = AttributedString(text)
        guard !words.isEmpty else { return marked }
        for range in ranges(of: words, in: text) {
            guard let lower = AttributedString.Index(range.lowerBound, within: marked),
                  let upper = AttributedString.Index(range.upperBound, within: marked) else { continue }
            marked[lower..<upper].backgroundColor = Color.yellow.opacity(0.32)
        }
        return marked
    }
}
