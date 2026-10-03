import SwiftUI

extension Color {
    /// The Kite Plus blue the app is tinted with.
    static let kite = Color("AccentColor")
}

/// The symbol shown for each topic.
nonisolated enum TopicStyle {
    static func symbol(for slug: String) -> String {
        switch slug {
        case "frontend": "chevron.left.forwardslash.chevron.right"
        case "backend": "server.rack"
        case "mobile": "iphone"
        case "ai": "sparkles"
        case "data": "chart.bar.xaxis"
        case "ops": "cloud"
        case "security": "lock.shield"
        case "languages": "curlybraces"
        case "tools": "wrench.and.screwdriver"
        case "design": "paintpalette"
        case "product": "lightbulb"
        case "career": "briefcase"
        case "life": "leaf"
        case "reading": "book"
        case "travel": "airplane"
        default: "number"
        }
    }
}
