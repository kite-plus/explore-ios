import Foundation

/// Parses the server's timestamps: RFC 3339 in UTC, with or without
/// fractional seconds of any length (Postgres sends microseconds).
nonisolated enum RFC3339 {
    static func date(from string: String) -> Date? {
        var base = string
        var fraction = 0.0
        if let dot = string.firstIndex(of: ".") {
            var end = string.index(after: dot)
            while end < string.endIndex, string[end].isASCII, string[end].isNumber {
                end = string.index(after: end)
            }
            fraction = Double("0" + string[dot..<end]) ?? 0
            base = String(string[..<dot] + string[end...])
        }
        guard let whole = try? Date(base, strategy: .iso8601) else { return nil }
        return whole.addingTimeInterval(fraction)
    }

    static func string(from date: Date) -> String {
        date.formatted(.iso8601)
    }

    static let decoding: JSONDecoder.DateDecodingStrategy = .custom { decoder in
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        guard let date = RFC3339.date(from: raw) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Not an RFC 3339 time: \(raw)")
        }
        return date
    }
}
