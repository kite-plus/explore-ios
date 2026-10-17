import Foundation
import Testing
@testable import Explore

struct SearchTermsTests {
    @Test(arguments: [
        ("独立开发", ["独立开发"]),
        ("你好，世界", ["你好", "世界"]),
        ("Go 语言", ["go", "语言"]),
        ("go语言", ["go语言"]),
        ("rust - wasm", ["rust", "wasm"]),
        ("C++", ["c++"]),
        ("  ", []),
    ])
    func splitsWords(_ query: String, _ words: [String]) {
        #expect(SearchTerms.words(in: query) == words)
    }

    @Test func keepsEightWords() {
        #expect(SearchTerms.words(in: "a b c d e f g h i j").count == 8)
    }

    private func marked(_ text: String, _ query: String) -> [String] {
        SearchTerms.ranges(of: SearchTerms.words(in: query), in: text).map { String(text[$0]) }
    }

    @Test func marksChineseAsTyped() {
        #expect(marked("先回答这四个问题，再谈独立开发", "独立开发") == ["独立开发"])
        #expect(marked("独立开发者 1000 用户指南", "开发") == ["开发"])
    }

    @Test func marksOtherWordsWhole() {
        #expect(marked("Google: go, Go!", "go") == ["go", "Go"])
        #expect(marked("Learn C++ today", "c++") == ["C++"])
        #expect(marked("go语言入门", "go") == ["go"])
    }

    @Test func longerWordsWin() {
        #expect(marked("独立开发者", "独立 独立开发") == ["独立开发"])
    }

    @Test func marksEveryWord() {
        #expect(marked("SwiftUI and Swift Testing", "testing swift") == ["Swift", "Testing"])
    }

    @Test func snippetsKeepALateMatchInView() {
        let excerpt = "探讨编程方式的质变：如何使用 VSCode、Claude Code 和 OpenClaw 组合打造高效的独立开发工作流。"
        let snippet = SearchTerms.snippet(excerpt, words: ["独立开发"])
        #expect(snippet.hasPrefix("…"))
        #expect(snippet.hasSuffix("独立开发工作流。"))
        #expect(snippet.count < excerpt.count)
    }

    @Test func snippetsStartAtAWord() {
        let excerpt = "A long introduction that goes on for quite a while before the word appears: rust."
        #expect(SearchTerms.snippet(excerpt, words: ["rust"]) == "…appears: rust.")
    }

    @Test func earlyMatchesLeaveTheTextAlone() {
        let excerpt = "观点一：身份错位 —— 独立开发被当成了"
        #expect(SearchTerms.snippet(excerpt, words: ["独立开发"]) == excerpt)
        #expect(SearchTerms.snippet(excerpt, words: []) == excerpt)
    }
}

/// Search against canned answers, one host per test.
struct SearchTests {
    private let entries = """
    {"data":[{"id":"32817","title":"先回答这四个问题，再谈独立开发","url":"https://www.evan.xin/5124/",
    "blog":{"host":"www.evan.xin","name":"Evan's Space","site_url":"https://www.evan.xin/","language":"zh-Hans"}},
    {"id":"9142","title":"独立开发者 1000 用户指南 Fork","url":"https://ssshooter.com/1000-user-guide/"}],
    "next_cursor":"MToxNzgw","total":1000,"total_capped":true}
    """
    private let blogs = """
    {"data":[{"host":"www.ccgxk.com","name":"串串狗小刊","description":"独立开发","site_url":"https://www.ccgxk.com/"}],
    "next_cursor":null,"total":1,"total_capped":false}
    """

    private func client(_ host: String) -> APIClient {
        APIClient(server: URL(string: "https://\(host)")!, protocols: [StubProtocol.self])
    }

    @Test func decodesLaterPagesWithoutTotals() throws {
        let json = #"{"data":[],"next_cursor":null,"total":null}"#
        let page = try JSONDecoder().decode(SearchPage<Blog>.self, from: Data(json.utf8))
        #expect(page.total == nil)
        #expect(!page.totalCapped)
    }

    @Test func sendsTheQuery() async throws {
        let host = "search-query.test"
        StubProtocol.answer(host, body: #"{"data":[],"next_cursor":null,"total":0}"#)
        _ = try await client(host).searchEntries("C++ 入门", cursor: "abc", language: "zh", limit: 30)
        let request = try #require(StubProtocol.requests(to: host).first)
        let url = try #require(request.url)
        #expect(url.path() == "/api/v1/search/entries")
        // A bare "+" would reach the server as a space.
        #expect(url.query(percentEncoded: true)?.contains("q=C%2B%2B%20%E5%85%A5%E9%97%A8") == true)
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        #expect(items.first { $0.name == "q" }?.value == "C++ 入门")
        #expect(items.first { $0.name == "cursor" }?.value == "abc")
        #expect(items.first { $0.name == "lang" }?.value == "zh")
        #expect(items.first { $0.name == "limit" }?.value == "30")
    }

    @Test func findsPostsAndBlogs() async throws {
        let host = "search-found.test"
        StubProtocol.answer(host, path: "/api/v1/search/entries", body: entries)
        StubProtocol.answer(host, path: "/api/v1/search/blogs", body: blogs)
        let model = SearchModel()
        let query = SearchModel.Query(text: "独立开发", language: nil)
        await model.search(query, using: client(host))
        #expect(model.phase == .loaded)
        #expect(model.query == query)
        #expect(model.entries.map(\.id) == ["32817", "9142"])
        #expect(model.entryCount == 1000)
        #expect(model.entryCountCapped)
        #expect(model.entryCursor == "MToxNzgw")
        #expect(model.blogs.map(\.host) == ["www.ccgxk.com"])
        #expect(model.blogCount == 1)
        #expect(model.blogCursor == nil)

        model.reset()
        #expect(model.query == nil)
        #expect(model.isEmpty)
        #expect(model.phase == .idle)
    }

    @Test func serversBeforeSearchAreAskedOnce() async throws {
        let host = "search-missing.test"
        StubProtocol.answer(host, status: 404, body: #"{"error":{"code":"not_found","message":"Not found."}}"#)
        let model = SearchModel()
        let client = client(host)
        await model.search(SearchModel.Query(text: "go", language: nil), using: client)
        #expect(model.phase == .unsupported)
        let asked = StubProtocol.requests(to: host).count
        await model.search(SearchModel.Query(text: "rust", language: nil), using: client)
        #expect(model.phase == .unsupported)
        #expect(model.query?.text == "rust")
        #expect(StubProtocol.requests(to: host).count == asked)
    }

    @Test func failuresKeepTheirMessage() async throws {
        let host = "search-failed.test"
        StubProtocol.answer(host, status: 400, body: #"{"error":{"code":"invalid_request","message":"Too long."}}"#)
        let model = SearchModel()
        await model.search(SearchModel.Query(text: "x", language: nil), using: client(host))
        #expect(model.phase == .failed("Too long."))
    }
}
