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
