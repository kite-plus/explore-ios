import SwiftUI

enum AppTab: Hashable {
    case discover, blogs, me
}

/// The streams Discover switches between, as the website's tabs do.
enum DiscoverStream: String, CaseIterable, Identifiable {
    case latest, recommended, following

    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .latest: "Latest"
        case .recommended: "Recommended"
        case .following: "Following"
        }
    }
}

/// Sheets that any screen can ask for.
enum AppSheet: Identifiable {
    case signIn(SignInMode)
    case submit
    case report(ReportTarget)
    case claim(BlogRef)
    case share(ShareSubject)

    var id: String {
        switch self {
        case let .signIn(mode): "sign-in-\(mode)"
        case .submit: "submit"
        case let .report(target): "report-\(target.id)"
        case let .claim(blog): "claim-\(blog.host)"
        case let .share(subject): "share-\(subject.id)"
        }
    }
}

enum SignInMode: Hashable {
    case signIn, register
}

/// What a report is about: a whole blog or one of its posts.
struct ReportTarget: Hashable, Identifiable {
    let blogHost: String
    let blogName: String
    let entryID: String?
    let entryTitle: String?

    var id: String { entryID.map { "\(blogHost)/\($0)" } ?? blogHost }
}

struct Toast: Identifiable, Equatable {
    let id = UUID()
    let message: String
    let systemImage: String
    let isError: Bool
}

/// App-wide state: the server, the account, the tag list, follows and link
/// checks. Screens keep their own lists; this holds what several share.
@Observable
final class AppModel {
    static let defaultServer = URL(string: "https://explore.kite.plus")!

    var tab: AppTab = .discover
    var stream: DiscoverStream = .latest
    var sheet: AppSheet?
    /// A screen a link asked for, waiting for its tab's stack to show it.
    private(set) var pendingRoute: (tab: AppTab, route: Route)?
    /// A post the widget asked to open on the author's site.
    private(set) var pendingPost: URL?
    /// A post about to open, which RootView names for a moment first.
    private(set) var handoff: Handoff?
    /// Counts taps on Discover's tab while it shows. The streams sit in a
    /// pager the system cannot scroll to the top, so Discover does it.
    private(set) var discoverRetaps = 0
    /// Every blog, for searching; loaded the first time someone searches.
    let blogIndex = BlogIndex()
    private(set) var toast: Toast?

    private(set) var client: APIClient
    private(set) var user: User?
    private(set) var isRestoringSession = false
    private var restoringToken: String?
    private(set) var topics: [Topic] = []
    private(set) var notice = ""
    private(set) var registrationEnabled = true
    private(set) var followedHosts: Set<String> = []
    private(set) var pendingFollows: Set<String> = []
    private(set) var linkStates: [String: LinkState] = [:]
    private(set) var checkingLinks: Set<String> = []
    private(set) var submissionIDs: [String] = []
    /// Changes whenever the server or the account changes, so lists reload.
    private(set) var generation = 0

    private var toastTask: Task<Void, Never>?
    private var isLoadingTopics = false
    private var siteConfigLoadedAt: Date?

    var server: URL { client.server }
    var isSignedIn: Bool { user != nil }

    /// The utm_source added to links that leave the app: the server's host,
    /// as the website does.
    var sourceTag: String {
        let host = server.host(percentEncoded: false) ?? "explore"
        if let port = server.port { return "\(host):\(port)" }
        return host
    }

    init() {
        let server = Self.storedServer
        client = APIClient(server: server, sessionToken: Keychain.token(for: Self.key(for: server)))
        submissionIDs = Self.storedSubmissions(for: server)
    }

    /// Loads what every screen needs once: the tag list, the site notice and
    /// the session kept from last time.
    func bootstrap() async {
        async let topics: Void = loadTopics()
        async let config: Void = loadSiteConfig()
        async let session: Void = restoreSession()
        _ = await (topics, config, session)
    }

    // MARK: Topics and site settings

    func loadTopics() async {
        guard topics.isEmpty, !isLoadingTopics else { return }
        isLoadingTopics = true
        defer { isLoadingTopics = false }
        if let list = try? await client.topics() {
            topics = list
        }
    }

    func loadSiteConfig() async {
        guard let config = try? await client.siteConfig() else { return }
        notice = config.notice.trimmingCharacters(in: .whitespacesAndNewlines)
        registrationEnabled = config.registrationEnabled
        siteConfigLoadedAt = .now
    }

    /// Catches up when the app becomes active: whatever failed at launch,
    /// and a site notice older than ten minutes.
    func catchUp() async {
        async let topics: Void = loadTopics()
        async let session: Void = restoreSession()
        if siteConfigLoadedAt.map({ Date.now.timeIntervalSince($0) > 600 }) ?? true {
            await loadSiteConfig()
        }
        _ = await (topics, session)
    }

    func topic(_ slug: String) -> Topic? {
        topics.first { $0.slug == slug }
    }

    func topicName(_ slug: String) -> String? {
        topic(slug)?.name(in: .current)
    }

    // MARK: Session

    func restoreSession() async {
        let client = client
        guard let token = client.sessionToken, user == nil, restoringToken != token else { return }
        restoringToken = token
        isRestoringSession = true
        defer {
            if restoringToken == token {
                restoringToken = nil
                isRestoringSession = false
            }
        }
        // The answer only counts for the server and sign-in it was asked
        // about; the reader may have switched servers or signed in since.
        func isCurrent() -> Bool { client === self.client && client.sessionToken == token }
        do {
            let me = try await client.me()
            guard isCurrent() else { return }
            apply(me)
            await loadFollows()
        } catch let error as APIError where error.isUnauthorized {
            if isCurrent() { endSession() }
        } catch {
            // Offline: keep the token and try again when the app is active.
        }
    }

    func signIn(email: String, password: String) async throws {
        let (user, token) = try await client.signIn(email: email, password: password)
        startSession(user, token: token)
        await loadFollows()
    }

    func register(email: String, password: String, displayName: String) async throws {
        let (user, token) = try await client.register(email: email, password: password, displayName: displayName)
        startSession(user, token: token)
    }

    func signOut() async {
        try? await client.signOut()
        endSession()
        showToast(String(localized: "Signed out"), systemImage: "rectangle.portrait.and.arrow.right")
    }

    func updateName(_ name: String) async throws {
        apply(try await client.updateName(name))
    }

    func changePassword(current: String, new: String) async throws {
        try await client.changePassword(current: current, new: new)
    }

    func deleteAccount() async throws {
        try await client.deleteAccount()
        endSession()
    }

    private func startSession(_ user: User, token: String) {
        Keychain.setToken(token, for: Self.key(for: server))
        client.sessionToken = token
        apply(user)
        generation += 1
    }

    private func apply(_ user: User) {
        self.user = user
        client.csrfToken = user.csrfToken
    }

    private func endSession() {
        Keychain.setToken(nil, for: Self.key(for: server))
        client.sessionToken = nil
        client.csrfToken = nil
        user = nil
        followedHosts = []
        generation += 1
    }

    /// Signs out locally when the server no longer knows the session.
    func handleAuthError(_ error: Error) {
        if let error = error as? APIError, error.isUnauthorized, isSignedIn {
            endSession()
            sheet = .signIn(.signIn)
        }
    }

    // MARK: Follows

    func loadFollows() async {
        guard isSignedIn, let blogs = try? await client.subscriptions() else { return }
        followedHosts = Set(blogs.map(\.host))
    }

    func isFollowing(_ host: String) -> Bool {
        followedHosts.contains(host)
    }

    func setFollowedHosts(_ hosts: Set<String>) {
        followedHosts = hosts
    }

    /// Follows or unfollows a blog, asking the reader to sign in first.
    func toggleFollow(_ blog: BlogRef) async {
        guard isSignedIn else {
            sheet = .signIn(.signIn)
            return
        }
        let host = blog.host
        guard !pendingFollows.contains(host) else { return }
        let follow = !followedHosts.contains(host)
        pendingFollows.insert(host)
        defer { pendingFollows.remove(host) }
        withAnimation(.snappy) {
            if follow { followedHosts.insert(host) } else { followedHosts.remove(host) }
        }
        do {
            if follow {
                try await client.subscribe(host: host)
                showToast(String(localized: "Following \(blog.name)"), systemImage: "heart.fill")
            } else {
                try await client.unsubscribe(host: host)
                showToast(String(localized: "Unfollowed \(blog.name)"), systemImage: "heart.slash")
            }
            generation += 1
        } catch {
            withAnimation(.snappy) {
                if follow { followedHosts.remove(host) } else { followedHosts.insert(host) }
            }
            handleAuthError(error)
            showError(error)
        }
    }

    // MARK: Link checks

    func linkStatus(of entry: Entry) -> (status: LinkStatus, checkedAt: Date?) {
        if let state = linkStates[entry.id] {
            return (state.linkStatus, state.linkCheckedAt)
        }
        return (entry.linkStatus, entry.linkCheckedAt)
    }

    /// Asks Explore to check a post's link now and waits for the answer.
    func checkLink(_ entry: Entry) async {
        guard !checkingLinks.contains(entry.id) else { return }
        checkingLinks.insert(entry.id)
        defer { checkingLinks.remove(entry.id) }
        do {
            var state = try await client.checkLink(entryID: entry.id)
            var polls = 0
            while state.checking, polls < 12 {
                try await Task.sleep(for: .seconds(1.5))
                state = try await client.linkState(entryID: entry.id)
                polls += 1
            }
            withAnimation(.snappy) { linkStates[entry.id] = state }
        } catch {
            showError(error)
        }
    }

    // MARK: Submissions kept on this device

    func rememberSubmission(_ id: String) {
        submissionIDs.removeAll { $0 == id }
        submissionIDs.insert(id, at: 0)
        Self.storeSubmissions(submissionIDs, for: server)
    }

    func forgetSubmission(_ id: String) {
        submissionIDs.removeAll { $0 == id }
        Self.storeSubmissions(submissionIDs, for: server)
    }

    // MARK: Server

    var isDefaultServer: Bool { server == Self.defaultServer }

    func switchServer(to url: URL) async {
        UserDefaults.standard.set(url.absoluteString, forKey: Self.serverKey)
        client = APIClient(server: url, sessionToken: Keychain.token(for: Self.key(for: url)))
        user = nil
        topics = []
        notice = ""
        followedHosts = []
        linkStates = [:]
        submissionIDs = Self.storedSubmissions(for: url)
        generation += 1
        await bootstrap()
    }

    // MARK: Links into the app

    /// Opens explore:// links, and website addresses with the same paths:
    /// /blogs/{host}, /topics/{slug}, /submissions/{id}, /submit, /sign-in,
    /// the streams /recommended and /following, and the tab names.
    func open(_ url: URL) {
        var parts = url.pathComponents.filter { $0 != "/" }
        if url.scheme == "explore", let host = url.host(percentEncoded: false) {
            parts.insert(host, at: 0)
        }
        if parts.first == "en" { parts.removeFirst() }
        switch (parts.first, parts.dropFirst().first) {
        case ("open", _):
            let target = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first { $0.name == "url" }?.value
                .flatMap(URL.init(string:))
            if let target, ["http", "https"].contains(target.scheme?.lowercased() ?? "") {
                pendingPost = target
            }
        case let ("blogs", host?):
            let host = host.lowercased()
            show(.blog(BlogRef(host: host, name: host, siteURL: "https://\(host)/", language: "")), in: .blogs)
        case ("blogs", nil):
            tab = .blogs
        case let ("topics", slug?):
            show(.topic(slug), in: .discover)
        case let ("submissions", id?):
            show(.submission(id), in: .me)
        case ("submit", _):
            sheet = .submit
        case ("sign-in", _), ("login", _):
            sheet = isSignedIn ? nil : .signIn(.signIn)
        case (nil, _):
            show(.latest)
        case ("recommended", _):
            show(.recommended)
        case ("following", _):
            show(.following)
        case ("me", _), ("account", _):
            tab = .me
        case ("search", _):
            show(.search, in: .discover)
        case ("about", _):
            show(.about, in: .me)
        default:
            tab = .discover
        }
    }

    private func show(_ route: Route, in tab: AppTab) {
        self.tab = tab
        pendingRoute = (tab, route)
    }

    private func show(_ stream: DiscoverStream) {
        tab = .discover
        self.stream = stream
    }

    /// The tab bar's choice, which also tells a tap on the current tab.
    func select(_ tab: AppTab) {
        if tab == self.tab, tab == .discover {
            discoverRetaps += 1
        }
        self.tab = tab
    }

    /// Opens a post on the author's site by way of a moment that names it,
    /// as the website's transition page does, unless the reader turned that
    /// off.
    func openPost(_ entry: Entry, blog: BlogRef?) {
        guard handoff == nil, let url = URL(string: entry.url),
              ["http", "https"].contains(url.scheme?.lowercased() ?? "") else { return }
        guard Preferences.showsHandoff else {
            LinkOpener.open(url, source: sourceTag)
            return
        }
        handoff = Handoff(url: url, title: entry.title, blog: blog)
    }

    func endHandoff(_ id: UUID) {
        if handoff?.id == id { handoff = nil }
    }

    func takePendingPost() -> URL? {
        defer { pendingPost = nil }
        return pendingPost
    }

    /// Hands the pending screen to the stack of the given tab, once.
    func takePendingRoute(for tab: AppTab) -> Route? {
        guard let pending = pendingRoute, pending.tab == tab else { return nil }
        pendingRoute = nil
        return pending.route
    }

    // MARK: Toasts

    func showToast(_ message: String, systemImage: String = "checkmark.circle.fill", isError: Bool = false) {
        toastTask?.cancel()
        withAnimation(.bouncy) {
            toast = Toast(message: message, systemImage: systemImage, isError: isError)
        }
        toastTask = Task {
            try? await Task.sleep(for: .seconds(2.6))
            guard !Task.isCancelled else { return }
            withAnimation(.smooth) { toast = nil }
        }
    }

    func showError(_ error: Error) {
        guard !error.isCancellation else { return }
        showToast(error.readableMessage, systemImage: "exclamationmark.triangle.fill", isError: true)
    }

    func dismissToast() {
        toastTask?.cancel()
        withAnimation(.smooth) { toast = nil }
    }

    // MARK: Storage

    private static let serverKey = "server"

    private static var storedServer: URL {
        if let raw = UserDefaults.standard.string(forKey: serverKey), let url = URL(string: raw) {
            return url
        }
        return defaultServer
    }

    static func key(for server: URL) -> String {
        var raw = server.absoluteString
        while raw.hasSuffix("/") { raw.removeLast() }
        return raw
    }

    private static func storedSubmissions(for server: URL) -> [String] {
        UserDefaults.standard.stringArray(forKey: "submissions:" + key(for: server)) ?? []
    }

    private static func storeSubmissions(_ ids: [String], for server: URL) {
        UserDefaults.standard.set(Array(ids.prefix(50)), forKey: "submissions:" + key(for: server))
    }
}
