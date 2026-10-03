import Foundation
import Testing
@testable import Explore

struct SourceTagTests {
    private let source = "explore.kite.plus"

    @Test func addsSource() {
        let url = URL(string: "https://blog.example.com/posts/hello/")!
        #expect(SourceTag.tagged(url, source: source).absoluteString == "https://blog.example.com/posts/hello/?utm_source=explore.kite.plus")
    }

    @Test func keepsTheQueryAsWritten() {
        let url = URL(string: "https://blog.example.com/?p=12&a=b%20c")!
        #expect(SourceTag.tagged(url, source: source).absoluteString == "https://blog.example.com/?p=12&a=b%20c&utm_source=explore.kite.plus")
    }

    @Test func keepsTheFragment() {
        let url = URL(string: "https://blog.example.com/post#comments")!
        #expect(SourceTag.tagged(url, source: source).absoluteString == "https://blog.example.com/post?utm_source=explore.kite.plus#comments")
    }

    @Test func leavesTheAuthorsSourceAlone() {
        let url = URL(string: "https://blog.example.com/?utm_source=newsletter")!
        #expect(SourceTag.tagged(url, source: source) == url)
    }

    @Test func leavesOtherSchemesAlone() {
        let url = URL(string: "mailto:someone@example.com")!
        #expect(SourceTag.tagged(url, source: source) == url)
    }
}

struct PaletteTests {
    // Expected values come from the website's avatarColor in lib/avatar.ts.
    @Test(arguments: [
        ("blog.hikarilan.life", 5),
        ("www.amigoer.com", 4),
        ("example.com", 7),
        ("blog.example.com", 3),
        ("中文.example", 4),
    ])
    func matchesTheWebsite(host: String, index: Int) {
        #expect(Palette.avatarIndex(for: host) == index)
    }

    @Test func initials() {
        #expect(Palette.initial(of: "  kite ") == "K")
        #expect(Palette.initial(of: "贺兰星辰") == "贺")
        #expect(Palette.initial(of: "") == "?")
    }
}

struct FormattingTests {
    @Test func normalizesAddresses() {
        #expect(Formatting.normalizedAddress(" blog.example.com ") == "https://blog.example.com")
        #expect(Formatting.normalizedAddress("http://blog.example.com") == "http://blog.example.com")
        #expect(Formatting.normalizedAddress("") == "")
    }

    @Test func displayHosts() {
        #expect(Formatting.displayHost("www.amigoer.com") == "amigoer.com")
        #expect(Formatting.displayHost("blog.example.com") == "blog.example.com")
    }

    @Test func generators() {
        #expect(Formatting.generatorName("wordpress") == "WordPress")
        #expect(Formatting.generatorName("unknown") == nil)
    }

    @Test func recentTimesAreRelative() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        #expect(Formatting.relative(now.addingTimeInterval(-20), now: now) == String(localized: "just now"))
        #expect(Formatting.relative(now.addingTimeInterval(-30 * 24 * 3600), now: now) == Formatting.day(now.addingTimeInterval(-30 * 24 * 3600), now: now))
    }
}

struct OPMLTests {
    private let blog = Blog(
        host: "blog.example.com", name: "Tom & Jerry's <Blog>", about: "",
        siteURL: "https://blog.example.com/", feedURL: "https://blog.example.com/feed?a=1&b=2",
        language: "en", generator: "hugo", lastPublishedAt: nil
    )

    @Test func escapesText() {
        #expect(OPMLDocument.escape(#"a & b < c > d " e ' f"#) == "a &amp; b &lt; c &gt; d &quot; e &apos; f")
    }

    @Test func listsEachBlog() {
        let xml = OPMLDocument(title: "Follows", blogs: [blog]).xml
        #expect(xml.hasPrefix(#"<?xml version="1.0" encoding="UTF-8"?>"#))
        #expect(xml.contains(#"text="Tom &amp; Jerry&apos;s &lt;Blog&gt;""#))
        #expect(xml.contains(#"xmlUrl="https://blog.example.com/feed?a=1&amp;b=2""#))
        #expect(XMLParser(data: Data(xml.utf8)).parse())
        #expect(xml.components(separatedBy: "<outline ").count == 2)
    }
}

@MainActor
struct DeepLinkTests {
    @Test func opensBlogs() throws {
        let app = AppModel()
        app.open(URL(string: "explore://blogs/Blog.Example.com")!)
        #expect(app.tab == .blogs)
        let route = try #require(app.takePendingRoute(for: .blogs))
        guard case let .blog(ref, _) = route else {
            Issue.record("expected a blog route, got \(route)")
            return
        }
        #expect(ref.host == "blog.example.com")
        #expect(app.takePendingRoute(for: .blogs) == nil)
    }

    @Test func opensWebsiteAddresses() {
        let app = AppModel()
        app.open(URL(string: "https://explore.kite.plus/en/topics/ai")!)
        #expect(app.tab == .search)
        #expect(app.takePendingRoute(for: .search) == .topic("ai"))
    }

    @Test func opensSheetsAndTabs() {
        let app = AppModel()
        app.open(URL(string: "explore://submit")!)
        #expect(app.sheet?.id == "submit")
        app.open(URL(string: "explore://following")!)
        #expect(app.tab == .following)
        app.open(URL(string: "explore://nowhere")!)
        #expect(app.tab == .discover)
    }

    @Test func opensPostsFromTheWidget() {
        let app = AppModel()
        app.open(URL(string: "explore://open?url=https%3A%2F%2Fblog.example.com%2Fp%3Fid%3D1")!)
        #expect(app.takePendingPost() == URL(string: "https://blog.example.com/p?id=1"))
        #expect(app.takePendingPost() == nil)
        app.open(URL(string: "explore://open?url=javascript:alert(1)")!)
        #expect(app.takePendingPost() == nil)
    }

    @Test func routesWaitForTheirTab() {
        let app = AppModel()
        app.open(URL(string: "explore://submissions/abc")!)
        #expect(app.takePendingRoute(for: .discover) == nil)
        #expect(app.takePendingRoute(for: .me) == .submission("abc"))
    }
}
