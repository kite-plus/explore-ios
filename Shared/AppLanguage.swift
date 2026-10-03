import Foundation

/// The interface language. The app ships in Chinese and English and follows
/// the localization iOS picked for it; posts always keep their own language.
nonisolated enum AppLanguage: String, Sendable {
    case zh, en

    static var current: AppLanguage {
        let preferred = Bundle.main.preferredLocalizations.first ?? "en"
        return preferred.hasPrefix("zh") ? .zh : .en
    }

    /// Sent as Accept-Language so error messages and check hints match the
    /// interface.
    var acceptLanguage: String { self == .zh ? "zh-CN" : "en" }

    /// Explore's web pages for this language live under this path prefix.
    var webPrefix: String { self == .zh ? "" : "/en" }
}
