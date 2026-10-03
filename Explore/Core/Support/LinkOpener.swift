import SafariServices
import UIKit

enum Preferences {
    static let openInSafari = "links.openInSafari"
    static let readerMode = "links.readerMode"
}

/// Opens links that leave Explore. Posts and blog homepages are read on the
/// author's own site, in Safari's view inside the app unless the reader
/// prefers Safari itself; the app never sees what happens there.
enum LinkOpener {
    static func open(_ url: URL, source: String? = nil) {
        let target = source.map { SourceTag.tagged(url, source: $0) } ?? url
        let isWeb = ["http", "https"].contains(target.scheme?.lowercased() ?? "")
        if !isWeb || UserDefaults.standard.bool(forKey: Preferences.openInSafari) {
            UIApplication.shared.open(target)
            return
        }
        let configuration = SFSafariViewController.Configuration()
        configuration.entersReaderIfAvailable = UserDefaults.standard.bool(forKey: Preferences.readerMode)
        configuration.barCollapsingEnabled = true
        let safari = SFSafariViewController(url: target, configuration: configuration)
        safari.dismissButtonStyle = .close
        guard let presenter = topViewController() else {
            UIApplication.shared.open(target)
            return
        }
        presenter.present(safari, animated: true)
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
