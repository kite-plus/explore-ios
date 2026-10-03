import SwiftUI

extension Color {
    nonisolated init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }

    /// The Kite Plus blue the app is tinted with.
    static let kite = Color("AccentColor")
}

nonisolated enum Palette {
    /// The website's avatar colors (Tailwind 600s), in the same order, so a
    /// blog gets the same color on the web and in the app.
    static let avatars: [Color] = [
        0xE11D48, 0xEA580C, 0xD97706, 0x059669, 0x0D9488,
        0x0284C7, 0x4F46E5, 0x7C3AED, 0xC026D3, 0x475569,
    ].map { Color(hex: $0) }

    static func color(for host: String) -> Color {
        avatars[avatarIndex(for: host)]
    }

    /// Mirrors avatarColor in the web's lib/avatar.ts.
    static func avatarIndex(for host: String) -> Int {
        var hash: UInt32 = 0
        for scalar in host.unicodeScalars {
            hash = hash &* 31 &+ scalar.value
        }
        return Int(hash % UInt32(avatars.count))
    }

    static func initial(of name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = trimmed.first else { return "?" }
        return String(first).uppercased()
    }
}

/// How each topic looks: a symbol and a pair of colors for its gradient.
nonisolated struct TopicStyle: Sendable {
    let symbol: String
    let colors: [Color]

    var color: Color { colors[0] }

    var gradient: LinearGradient {
        LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    static func of(_ slug: String) -> TopicStyle {
        switch slug {
        case "frontend": TopicStyle(symbol: "chevron.left.forwardslash.chevron.right", colors: [Color(hex: 0x2563EB), Color(hex: 0x06B6D4)])
        case "backend": TopicStyle(symbol: "server.rack", colors: [Color(hex: 0x4F46E5), Color(hex: 0x3B82F6)])
        case "mobile": TopicStyle(symbol: "iphone", colors: [Color(hex: 0x0D9488), Color(hex: 0x22C55E)])
        case "ai": TopicStyle(symbol: "sparkles", colors: [Color(hex: 0x7C3AED), Color(hex: 0xEC4899)])
        case "data": TopicStyle(symbol: "chart.bar.xaxis", colors: [Color(hex: 0x0284C7), Color(hex: 0x6366F1)])
        case "ops": TopicStyle(symbol: "cloud", colors: [Color(hex: 0x0369A1), Color(hex: 0x38BDF8)])
        case "security": TopicStyle(symbol: "lock.shield", colors: [Color(hex: 0xDC2626), Color(hex: 0xF97316)])
        case "languages": TopicStyle(symbol: "curlybraces", colors: [Color(hex: 0xD97706), Color(hex: 0xEF4444)])
        case "tools": TopicStyle(symbol: "wrench.and.screwdriver", colors: [Color(hex: 0x475569), Color(hex: 0x0EA5E9)])
        case "design": TopicStyle(symbol: "paintpalette", colors: [Color(hex: 0xDB2777), Color(hex: 0xF59E0B)])
        case "product": TopicStyle(symbol: "lightbulb", colors: [Color(hex: 0xCA8A04), Color(hex: 0xF97316)])
        case "career": TopicStyle(symbol: "briefcase", colors: [Color(hex: 0x92400E), Color(hex: 0xD97706)])
        case "life": TopicStyle(symbol: "leaf", colors: [Color(hex: 0x16A34A), Color(hex: 0x84CC16)])
        case "reading": TopicStyle(symbol: "book", colors: [Color(hex: 0x059669), Color(hex: 0x14B8A6)])
        case "travel": TopicStyle(symbol: "airplane", colors: [Color(hex: 0xEA580C), Color(hex: 0xEC4899)])
        default: TopicStyle(symbol: "number", colors: [Color(hex: 0x4A77D6), Color(hex: 0x7C3AED)])
        }
    }
}
