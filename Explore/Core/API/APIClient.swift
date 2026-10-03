import Foundation

/// Talks to one Explore server (docs/design/api.md in the explore repo).
///
/// Anonymous requests carry no cookie at all. Once signed in, account
/// requests send the session cookie by hand and writes add the CSRF token;
/// the token lives in the keychain rather than a shared cookie jar.
final class APIClient {
    let server: URL
    var sessionToken: String?
    var csrfToken: String?

    private let session: URLSession
    private let decoder: JSONDecoder

    init(server: URL, sessionToken: String? = nil) {
        self.server = server
        self.sessionToken = sessionToken
        let config = URLSessionConfiguration.default
        config.httpShouldSetCookies = false
        config.httpCookieAcceptPolicy = .never
        config.httpCookieStorage = nil
        config.urlCache = URLCache(memoryCapacity: 8 << 20, diskCapacity: 32 << 20)
        config.timeoutIntervalForRequest = 20
        session = URLSession(configuration: config)
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = RFC3339.decoding
    }

    // MARK: Addresses

    func imageURL(_ path: String) -> URL {
        server.appending(path: path.hasPrefix("/") ? String(path.dropFirst()) : path)
    }

    func faviconURL(host: String) -> URL {
        server.appending(path: "api/v1/blogs/\(host)/favicon")
    }

    /// The blog's page on the Explore website, for sharing.
    func webURL(blog host: String) -> URL {
        server.appending(path: "\(AppLanguage.current.webPrefix)/blogs/\(host)")
    }

    var feedURL: URL { server.appending(path: "feed.xml") }
    var opmlURL: URL { server.appending(path: "blogs.opml") }
    var aboutURL: URL { server.appending(path: "\(AppLanguage.current.webPrefix)/about") }
    var botURL: URL { server.appending(path: "bot") }

    // MARK: Reading

    /// The latest posts, or with order "recommended" the posts rated solid
    /// or standout.
    func entries(cursor: String?, language: String?, tag: String?, order: String? = nil, fresh: Bool = false) async throws -> Page<Entry> {
        var query = listQuery(cursor, language, tag)
        if let order { query.append(URLQueryItem(name: "order", value: order)) }
        return try await get("api/v1/entries", query: query, fresh: fresh)
    }

    func followingEntries(cursor: String?, language: String?, tag: String?) async throws -> Page<Entry> {
        try await get("api/v1/me/entries", query: listQuery(cursor, language, tag), signed: true)
    }

    func blogs(cursor: String?, language: String?, limit: Int = 30, fresh: Bool = false) async throws -> Page<Blog> {
        var query = listQuery(cursor, language, nil)
        query.append(URLQueryItem(name: "limit", value: String(limit)))
        return try await get("api/v1/blogs", query: query, fresh: fresh)
    }

    func blog(host: String, cursor: String?, fresh: Bool = false) async throws -> BlogPage {
        try await get("api/v1/blogs/\(host)", query: listQuery(cursor, nil, nil), fresh: fresh)
    }

    func topics() async throws -> [Topic] {
        let list: DataList<Topic> = try await get("api/v1/tags")
        return list.data
    }

    func siteConfig() async throws -> SiteConfig {
        try await get("api/v1/site-config", fresh: true)
    }

    // MARK: Link checks

    func linkState(entryID: String) async throws -> LinkState {
        try await get("api/v1/entries/\(entryID)/check", fresh: true)
    }

    func checkLink(entryID: String) async throws -> LinkState {
        try await send("POST", "api/v1/entries/\(entryID)/check", json: [:])
    }

    // MARK: Submissions

    func previewSubmission(siteURL: String, feedURL: String) async throws -> SubmissionPreview {
        try await send("POST", "api/v1/submissions/preview", json: [
            "site_url": siteURL, "feed_url": feedURL,
        ], timeout: 45)
    }

    func submit(siteURL: String, feedURL: String, note: String, title: String, description: String) async throws -> Submission {
        try await send("POST", "api/v1/submissions", json: [
            "site_url": siteURL, "feed_url": feedURL, "note": note,
            "title": title, "description": description,
        ], timeout: 45)
    }

    func submission(id: String) async throws -> Submission {
        try await get("api/v1/submissions/\(id)", fresh: true)
    }

    // MARK: Account

    /// Signs in and returns the user with the new session token.
    func signIn(email: String, password: String) async throws -> (User, String) {
        try await startSession("api/v1/auth/login", json: ["email": email, "password": password])
    }

    func register(email: String, password: String, displayName: String) async throws -> (User, String) {
        try await startSession("api/v1/auth/register", json: [
            "email": email, "password": password, "display_name": displayName,
        ])
    }

    func signOut() async throws {
        try await sendEmpty("POST", "api/v1/auth/logout", json: [:])
    }

    func me() async throws -> User {
        try await get("api/v1/me", signed: true)
    }

    func updateName(_ name: String) async throws -> User {
        try await send("PATCH", "api/v1/me", json: ["display_name": name], signed: true)
    }

    func changePassword(current: String, new: String) async throws {
        try await sendEmpty("PUT", "api/v1/me/password", json: [
            "current_password": current, "new_password": new,
        ])
    }

    func deleteAccount() async throws {
        try await sendEmpty("DELETE", "api/v1/me", json: nil)
    }

    func subscriptions() async throws -> [Blog] {
        let list: DataList<Blog> = try await get("api/v1/me/subscriptions", signed: true)
        return list.data
    }

    func subscribe(host: String) async throws {
        try await sendEmpty("PUT", "api/v1/me/subscriptions/\(host)", json: nil)
    }

    func unsubscribe(host: String) async throws {
        try await sendEmpty("DELETE", "api/v1/me/subscriptions/\(host)", json: nil)
    }

    func ownedBlogs() async throws -> [Blog] {
        let list: DataList<Blog> = try await get("api/v1/me/blogs", signed: true)
        return list.data
    }

    func startClaim(host: String) async throws -> ClaimChallenge {
        try await send("POST", "api/v1/me/blog-claims/\(host)", json: [:], signed: true)
    }

    func verifyClaim(host: String) async throws {
        try await sendEmpty("POST", "api/v1/me/blog-claims/\(host)/verify", json: [:])
    }

    func report(blogHost: String, entryID: String?, reason: String) async throws {
        var body: [String: Any] = [
            "target_type": entryID == nil ? "blog" : "entry",
            "blog_host": blogHost,
            "reason": reason,
        ]
        if let entryID, let id = Int64(entryID) {
            body["entry_id"] = id
        }
        try await sendEmpty("POST", "api/v1/reports", json: body)
    }

    // MARK: Plumbing

    private func listQuery(_ cursor: String?, _ language: String?, _ tag: String?) -> [URLQueryItem] {
        var items: [URLQueryItem] = []
        if let cursor { items.append(URLQueryItem(name: "cursor", value: cursor)) }
        if let language { items.append(URLQueryItem(name: "lang", value: language)) }
        if let tag { items.append(URLQueryItem(name: "tag", value: tag)) }
        return items
    }

    private func request(
        _ method: String, _ path: String, query: [URLQueryItem] = [], json: [String: Any]? = nil,
        signed: Bool = false, fresh: Bool = false, timeout: TimeInterval? = nil
    ) throws -> URLRequest {
        var url = server.appending(path: path)
        if !query.isEmpty { url.append(queryItems: query) }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(AppLanguage.current.acceptLanguage, forHTTPHeaderField: "Accept-Language")
        if fresh { request.cachePolicy = .reloadIgnoringLocalCacheData }
        if let timeout { request.timeoutInterval = timeout }
        if let json {
            request.httpBody = try JSONSerialization.data(withJSONObject: json)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        if signed {
            guard let sessionToken else {
                throw APIError.server(
                    status: 401, code: "unauthorized", message: String(localized: "Sign in first."),
                    submissionID: nil, report: nil
                )
            }
            request.setValue("explore_session=\(sessionToken)", forHTTPHeaderField: "Cookie")
            if method != "GET", let csrfToken {
                request.setValue(csrfToken, forHTTPHeaderField: "X-CSRF-Token")
            }
            request.cachePolicy = .reloadIgnoringLocalCacheData
        }
        return request
    }

    private func perform(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError {
            if error.code == .cancelled { throw CancellationError() }
            throw APIError(error)
        }
        guard let http = response as? HTTPURLResponse else {
            throw APIError.invalidResponse("no HTTP response")
        }
        guard (200..<300).contains(http.statusCode) else {
            throw APIError(status: http.statusCode, data: data, decoder: decoder)
        }
        return (data, http)
    }

    private func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            return try decoder.decode(type, from: data)
        } catch {
            throw APIError.invalidResponse(String(describing: error))
        }
    }

    private func get<T: Decodable>(
        _ path: String, query: [URLQueryItem] = [], signed: Bool = false, fresh: Bool = false
    ) async throws -> T {
        let (data, _) = try await perform(request("GET", path, query: query, signed: signed, fresh: fresh))
        return try decode(T.self, from: data)
    }

    private func send<T: Decodable>(
        _ method: String, _ path: String, json: [String: Any]?, signed: Bool = false, timeout: TimeInterval? = nil
    ) async throws -> T {
        let (data, _) = try await perform(request(method, path, json: json, signed: signed, timeout: timeout))
        return try decode(T.self, from: data)
    }

    /// Account writes answer 201 or 204 with no body worth reading.
    private func sendEmpty(_ method: String, _ path: String, json: [String: Any]?) async throws {
        _ = try await perform(request(method, path, json: json, signed: true))
    }

    private func startSession(_ path: String, json: [String: Any]) async throws -> (User, String) {
        let (data, response) = try await perform(request("POST", path, json: json))
        let user = try decode(User.self, from: data)
        var fields: [String: String] = [:]
        for case let (key as String, value as String) in response.allHeaderFields {
            fields[key] = value
        }
        let cookies = HTTPCookie.cookies(withResponseHeaderFields: fields, for: response.url ?? server)
        guard let token = cookies.first(where: { $0.name == "explore_session" })?.value else {
            throw APIError.invalidResponse("no session cookie")
        }
        return (user, token)
    }
}
