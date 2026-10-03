import Foundation

nonisolated enum Formatting {
    /// "3 hours ago" within a week and a date after that, as the website shows.
    static func relative(_ date: Date, now: Date = .now) -> String {
        let elapsed = now.timeIntervalSince(date)
        guard elapsed >= 0, elapsed < 7 * 24 * 3600 else {
            return day(date, now: now)
        }
        if elapsed < 60 {
            return String(localized: "just now")
        }
        return date.formatted(.relative(presentation: .named, unitsStyle: .wide))
    }

    /// A calendar date, with the year only when it is not this year.
    static func day(_ date: Date, now: Date = .now) -> String {
        let calendar = Calendar.current
        if calendar.component(.year, from: date) == calendar.component(.year, from: now) {
            return date.formatted(.dateTime.month(.abbreviated).day())
        }
        return date.formatted(.dateTime.year().month(.abbreviated).day())
    }

    static func dateTime(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .shortened)
    }

    /// The language a blog declares, named in the interface language.
    static func languageName(_ code: String) -> String? {
        let trimmed = code.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        let language = Locale.Language(identifier: trimmed)
        let base = language.languageCode?.identifier ?? trimmed
        return Locale.current.localizedString(forLanguageCode: base) ?? trimmed
    }

    static func generatorName(_ raw: String) -> String? {
        switch raw.lowercased() {
        case "wordpress": "WordPress"
        case "halo": "Halo"
        case "hugo": "Hugo"
        case "hexo": "Hexo"
        case "typecho": "Typecho"
        case "jekyll": "Jekyll"
        case "ghost": "Ghost"
        case "kite": "Kite"
        case "other": String(localized: "Other")
        default: nil
        }
    }

    /// A host for display, without "www.".
    static func displayHost(_ host: String) -> String {
        host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
    }

    /// Accepts what people type into an address field: adds https:// when
    /// the scheme is missing and trims spaces.
    static func normalizedAddress(_ input: String) -> String {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        if trimmed.range(of: "^[a-zA-Z][a-zA-Z0-9+.-]*://", options: .regularExpression) != nil {
            return trimmed
        }
        return "https://" + trimmed
    }
}
