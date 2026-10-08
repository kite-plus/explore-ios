import SafariServices
import UIKit

enum Preferences {
    static let openInSafari = "links.openInSafari"
    static let readerMode = "links.readerMode"
    static let handoff = "links.handoff"
    static let dimsRead = "reading.dimsRead"

    /// Whether a post opens by way of the transition page: on until the
    /// reader turns it off.
    static var showsHandoff: Bool {
        UserDefaults.standard.object(forKey: handoff) as? Bool ?? true
    }

    /// Whether posts the reader opened are remembered and dimmed: on until
    /// the reader turns it off.
    static var dimsReadPosts: Bool {
        UserDefaults.standard.object(forKey: dimsRead) as? Bool ?? true
    }
}

/// Opens links that leave Explore. Posts and blog homepages are read on the
/// author's own site, in Safari's view inside the app unless the reader
/// prefers Safari itself; the app never sees what happens there.
enum LinkOpener {
    /// Opens a link that leaves Explore. done runs once it is open, with
    /// Safari's view covering the app or Safari in front, or at once when
    /// it cannot be opened. actions add the app's items to the share menu
    /// of Safari's view.
    static func open(
        _ url: URL, source: String? = nil, actions: PostActions? = nil, done: (@MainActor @Sendable () -> Void)? = nil
    ) {
        // Only web pages: a server could list other schemes, which would
        // hand the tap to whatever app claims them.
        guard isWeb(url) else {
            done?()
            return
        }
        let target = source.map { SourceTag.tagged(url, source: $0) } ?? url
        if UserDefaults.standard.bool(forKey: Preferences.openInSafari) {
            UIApplication.shared.open(target) { _ in done?() }
            return
        }
        let configuration = SFSafariViewController.Configuration()
        configuration.entersReaderIfAvailable = UserDefaults.standard.bool(forKey: Preferences.readerMode)
        configuration.barCollapsingEnabled = true
        let safari = SFSafariViewController(url: target, configuration: configuration)
        safari.dismissButtonStyle = .close
        guard let presenter = topViewController() else {
            UIApplication.shared.open(target) { _ in done?() }
            return
        }
        actions?.attach(to: safari)
        presenter.present(safari, animated: true) { done?() }
    }

    static func openInSafari(_ url: URL, source: String? = nil) {
        guard isWeb(url) else { return }
        UIApplication.shared.open(source.map { SourceTag.tagged(url, source: $0) } ?? url)
    }

    private static func isWeb(_ url: URL) -> Bool {
        ["http", "https"].contains(url.scheme?.lowercased() ?? "")
    }

    private static func topViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let scene = scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
        var top = scene?.keyWindow?.rootViewController
        while let presented = top?.presentedViewController, !presented.isBeingDismissed {
            top = presented
        }
        return top
    }
}
