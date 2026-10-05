import SafariServices
import SwiftUI

/// What the app adds to the share menu of Safari's view while a post is
/// open there: the post's share card, following its blog, and the blog's
/// page in the app. Each item shows only while the view is still on the
/// post, or on the blog's site, since the reader can follow links away.
final class PostActions: NSObject, SFSafariViewControllerDelegate {
    private let entry: Entry
    private let blog: BlogRef?
    private let app: AppModel
    private weak var safari: SFSafariViewController?

    /// Safari's view holds its delegate weakly; this keeps the open one.
    private static var current: PostActions?

    init(entry: Entry, blog: BlogRef?, app: AppModel) {
        self.entry = entry
        self.blog = blog ?? entry.blog
        self.app = app
    }

    func attach(to safari: SFSafariViewController) {
        self.safari = safari
        safari.delegate = self
        Self.current = self
        ToastWindow.show(for: app)
    }

    func safariViewController(_ controller: SFSafariViewController, activityItemsFor URL: URL, title: String?) -> [UIActivity] {
        var items: [UIActivity] = []
        if let post = Foundation.URL(string: entry.url), Self.samePage(URL, post) {
            items.append(AppActivity(type: "card", title: String(localized: "Share as Card"), symbol: "photo.on.rectangle") { [weak self] in
                self?.showCard()
            })
        }
        if let blog, Self.sameSite(URL, host: blog.host) {
            let following = app.isFollowing(blog.host)
            items.append(
                AppActivity(
                    type: "follow",
                    title: following ? String(localized: "Unfollow \(blog.name)") : String(localized: "Follow \(blog.name)"),
                    symbol: following ? "heart.slash" : "heart"
                ) { [weak self] in
                    self?.toggleFollow(blog)
                })
            items.append(AppActivity(type: "blog", title: String(localized: "View Blog in Kite"), symbol: "square.grid.2x2") { [weak self] in
                self?.close { $0.showBlog(blog) }
            })
        }
        return items
    }

    func safariViewControllerDidFinish(_ controller: SFSafariViewController) {
        finish()
    }

    private func showCard() {
        afterMenu { safari in
            let host = UIHostingController<AnyView>(rootView: AnyView(EmptyView()))
            host.rootView = AnyView(
                ShareSheet(subject: .post(self.entry, self.blog)) { [weak host] in
                    host?.dismiss(animated: true)
                }
                .environment(self.app))
            safari.present(host, animated: true)
        }
    }

    private func toggleFollow(_ blog: BlogRef) {
        guard app.isSignedIn else {
            close { $0.sheet = .signIn(.signIn) }
            return
        }
        Task { await app.toggleFollow(blog) }
    }

    /// Closes Safari's view, then does what comes next in the app.
    private func close(then next: @escaping @MainActor (AppModel) -> Void) {
        let app = app
        afterMenu { safari in
            self.finish()
            safari.presentingViewController?.dismiss(animated: true) { next(app) }
        }
    }

    /// Waits for the share menu to leave Safari's view, which cannot
    /// present anything else while the menu is still on it.
    private func afterMenu(_ body: @escaping @MainActor (SFSafariViewController) -> Void) {
        Task {
            for _ in 0..<40 where safari?.presentedViewController != nil {
                try? await Task.sleep(for: .milliseconds(25))
            }
            if let safari { body(safari) }
        }
    }

    private func finish() {
        ToastWindow.hide()
        if Self.current === self { Self.current = nil }
    }

    /// Whether two addresses are the same page, allowing for what a visit
    /// changes on the way: the scheme, www, a trailing slash, the query
    /// and the fragment.
    nonisolated static func samePage(_ a: URL, _ b: URL) -> Bool {
        guard let hostA = a.host(), let hostB = b.host() else { return false }
        return siteHost(hostA) == siteHost(hostB) && trimmedPath(a) == trimmedPath(b)
    }

    /// Whether an address is on the blog's own site.
    nonisolated static func sameSite(_ url: URL, host: String) -> Bool {
        guard let urlHost = url.host() else { return false }
        return siteHost(urlHost) == siteHost(host)
    }

    private nonisolated static func siteHost(_ host: String) -> String {
        let host = host.lowercased()
        return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
    }

    private nonisolated static func trimmedPath(_ url: URL) -> String {
        var path = url.path(percentEncoded: false)
        while path.hasSuffix("/") { path.removeLast() }
        return path
    }
}

/// A share menu item that runs in the app.
private nonisolated final class AppActivity: UIActivity {
    private let type: String
    private let title: String
    private let symbol: String
    private let action: @MainActor @Sendable () -> Void

    init(type: String, title: String, symbol: String, action: @escaping @MainActor @Sendable () -> Void) {
        self.type = type
        self.title = title
        self.symbol = symbol
        self.action = action
    }

    override class var activityCategory: UIActivity.Category { .action }
    override var activityType: UIActivity.ActivityType? { UIActivity.ActivityType("plus.kite.explore.\(type)") }
    override var activityTitle: String? { title }
    override var activityImage: UIImage? { UIImage(systemName: symbol) }

    override func canPerform(withActivityItems activityItems: [Any]) -> Bool { true }

    override func perform() {
        activityDidFinish(true)
        Task { @MainActor [action] in action() }
    }
}
