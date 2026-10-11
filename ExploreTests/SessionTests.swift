import Foundation
import Synchronization
import Testing
@testable import Explore

/// The client against canned answers: each test talks to a host of its own,
/// so they can run side by side.
struct SessionTests {
    private let user = #"{"id":"9f1","email":"a@example.com","display_name":"A","is_admin":false,"csrf_token":"csrf"}"#

    private func client(_ host: String, token: String? = nil) -> APIClient {
        APIClient(server: URL(string: "https://\(host)")!, sessionToken: token, protocols: [StubProtocol.self])
    }

    private func json(_ request: URLRequest?) throws -> [String: String] {
        let body = try #require(request?.httpBody)
        return try #require(try JSONSerialization.jsonObject(with: body) as? [String: String])
    }

    @Test func signedRequestsSendTheTokenAsBearerAndAsTheCookie() async throws {
        let host = "headers.test"
        StubProtocol.answer(host, status: 204)
        let client = client(host, token: "tok")
        client.csrfToken = "csrf"
        try await client.subscribe(host: "blog.example.com")
        _ = try? await client.me()
        let sent = StubProtocol.requests(to: host)
        try #require(sent.count == 2)
        let write = sent[0]
        #expect(write.httpMethod == "PUT")
        #expect(write.value(forHTTPHeaderField: "Authorization") == "Bearer tok")
        #expect(write.value(forHTTPHeaderField: "Cookie") == "explore_session=tok")
        #expect(write.value(forHTTPHeaderField: "X-CSRF-Token") == "csrf")
        let read = sent[1]
        #expect(read.httpMethod == "GET")
        #expect(read.value(forHTTPHeaderField: "Authorization") == "Bearer tok")
        #expect(read.value(forHTTPHeaderField: "Cookie") == "explore_session=tok")
        #expect(read.value(forHTTPHeaderField: "X-CSRF-Token") == nil)
    }

    @Test func anonymousRequestsSendNoToken() async throws {
        let host = "anonymous.test"
        StubProtocol.answer(host, body: #"{"data":[]}"#)
        _ = try await client(host).topics()
        let request = try #require(StubProtocol.requests(to: host).first)
        #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
        #expect(request.value(forHTTPHeaderField: "Cookie") == nil)
    }

    @Test func passwordSignInNamesTheAppAndTakesTheTokenFromTheBody() async throws {
        let host = "login.test"
        StubProtocol.answer(host, body: #"{"token":"new-token","expires_at":"2026-11-10T08:00:00Z","user":\#(user)}"#)
        let (signedIn, token) = try await client(host).signIn(email: "a@example.com", password: "secret")
        #expect(token == "new-token")
        #expect(signedIn.email == "a@example.com")
        let request = try #require(StubProtocol.requests(to: host).first)
        #expect(request.url?.path() == "/api/v1/auth/login")
        #expect(try json(request) == ["email": "a@example.com", "password": "secret", "client": "ios"])
    }

    @Test func passwordSignInOnOlderServersTakesTheCookie() async throws {
        let host = "old-login.test"
        StubProtocol.answer(host, headers: ["Set-Cookie": "explore_session=old-token; Path=/; HttpOnly; SameSite=Lax"], body: user)
        let (signedIn, token) = try await client(host).signIn(email: "a@example.com", password: "secret")
        #expect(token == "old-token")
        #expect(signedIn.displayName == "A")
    }

    @Test func signInWithoutAnyTokenFails() async {
        let host = "no-token.test"
        StubProtocol.answer(host, body: user)
        await #expect(throws: APIError.invalidResponse("no session token")) {
            _ = try await client(host).signIn(email: "a@example.com", password: "secret")
        }
    }

    @Test func optionsOfOlderServersArePasswordOnly() async throws {
        let host = "old-options.test"
        StubProtocol.answer(host, status: 404, body: #"{"error":{"code":"not_found","message":"Not found."}}"#)
        #expect(try await client(host).authOptions() == .passwordOnly)
    }

    @Test func optionsAskInTheInterfaceLanguage() async throws {
        let host = "options.test"
        StubProtocol.answer(host, body: #"{"password":true,"oidc":{"name":"Kite Plus account","account_url":"https://id.example/me"}}"#)
        let options = try await client(host).authOptions()
        #expect(options.kitePlus?.name == "Kite Plus account")
        let request = try #require(StubProtocol.requests(to: host).first)
        #expect(request.url?.path() == "/api/v1/auth/options")
        #expect(request.value(forHTTPHeaderField: "Accept-Language") == AppLanguage.current.acceptLanguage)
    }

    @Test func optionsFailuresOtherThanNotFoundStayErrors() async {
        let host = "options-down.test"
        StubProtocol.answer(host, status: 503, body: "<html>down</html>")
        await #expect(throws: APIError.self) {
            _ = try await client(host).authOptions()
        }
    }

    @Test func exchangeSendsTheCodeWithTheVerifier() async throws {
        let host = "exchange.test"
        StubProtocol.answer(host, body: #"{"token":"app-token","expires_at":"2026-11-10T08:00:00Z","user":\#(user)}"#)
        let (signedIn, token) = try await client(host).exchange(code: "the-code", verifier: "the-verifier")
        #expect(token == "app-token")
        #expect(signedIn.id == "9f1")
        let request = try #require(StubProtocol.requests(to: host).first)
        #expect(request.httpMethod == "POST")
        #expect(request.url?.path() == "/api/v1/auth/app/exchange")
        #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
        #expect(try json(request) == ["code": "the-code", "verifier": "the-verifier"])
    }

    @Test func exchangeRefusalKeepsItsCode() async {
        let host = "exchange-refused.test"
        StubProtocol.answer(host, status: 400, body: #"{"error":{"code":"invalid_grant","message":"Sign in again."}}"#)
        do {
            _ = try await client(host).exchange(code: "old", verifier: "v")
            Issue.record("expected the exchange to fail")
        } catch {
            #expect((error as? APIError)?.code == "invalid_grant")
        }
    }
}

/// Answers every request to a host with what a test set for it, and keeps
/// the requests, bodies included, for the test to read.
nonisolated final class StubProtocol: URLProtocol {
    private struct Answer: Sendable {
        let status: Int
        let headers: [String: String]
        let body: Data
    }

    private static let answers = Mutex<[String: Answer]>([:])
    private static let sent = Mutex<[String: [URLRequest]]>([:])

    static func answer(_ host: String, status: Int = 200, headers: [String: String] = [:], body: String = "") {
        let answer = Answer(status: status, headers: headers.merging(["Content-Type": "application/json"]) { a, _ in a }, body: Data(body.utf8))
        answers.withLock { $0[host] = answer }
    }

    static func requests(to host: String) -> [URLRequest] {
        sent.withLock { $0[host] ?? [] }
    }

    override class func canInit(with request: URLRequest) -> Bool { true }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let host = request.url?.host() ?? ""
        var kept = request
        if kept.httpBody == nil, let stream = request.httpBodyStream {
            kept.httpBody = Self.read(stream)
        }
        Self.sent.withLock { $0[host, default: []].append(kept) }
        let answer = Self.answers.withLock { $0[host] } ?? Answer(status: 404, headers: [:], body: Data())
        let response = HTTPURLResponse(url: request.url!, statusCode: answer.status, httpVersion: "HTTP/1.1", headerFields: answer.headers)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: answer.body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}

    private static func read(_ stream: InputStream) -> Data {
        stream.open()
        defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)
            guard count > 0 else { break }
            data.append(buffer, count: count)
        }
        return data
    }
}
