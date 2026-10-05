import CoreImage
import Foundation
import Testing
import UIKit
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

struct PostActionsTests {
    private let post = URL(string: "https://www.ixiqin.com/2026/09/%E4%BB%A5%E6%A3%8B/")!

    @Test func samePageAfterTheVisit() {
        let opened = URL(string: "http://ixiqin.com/2026/09/以棋?utm_source=explore.kite.plus#comments")!
        #expect(PostActions.samePage(opened, post))
    }

    @Test func anotherPageIsNot() {
        #expect(!PostActions.samePage(URL(string: "https://www.ixiqin.com/2026/08/other/")!, post))
        #expect(!PostActions.samePage(URL(string: "https://example.com/2026/09/%E4%BB%A5%E6%A3%8B/")!, post))
    }

    @Test func sameSiteWithOrWithoutWWW() {
        #expect(PostActions.sameSite(URL(string: "https://ixiqin.com/about/")!, host: "www.ixiqin.com"))
        #expect(!PostActions.sameSite(URL(string: "https://github.com/ixiqin")!, host: "www.ixiqin.com"))
    }
}

struct StreamItemTests {
    private func entry(_ id: String) -> Entry {
        Entry(
            id: id, title: id, url: "https://blog.example.com/\(id)", excerpt: nil, imagePath: nil,
            publishedAt: nil, tags: [], linkStatus: .unknown, linkCheckedAt: nil, blog: nil
        )
    }

    private func notice(_ id: String, at position: Int) -> Notice {
        Notice(id: id, kind: "notice", title: id, summary: "", url: "", sourceName: "Kite Plus", position: position, publishedAt: nil)
    }

    @Test func placesNoticesByPosition() {
        let items = StreamItem.items(
            entries: [entry("a"), entry("b")],
            notices: [notice("pinned", at: 0), notice("first", at: 1), notice("late", at: 9)]
        )
        #expect(items.map(\.id) == ["notice-pinned", "post-a", "notice-first", "post-b", "notice-late"])
    }

    @Test func splitsNoticeTextIntoParagraphs() {
        let text = "第一段。\r\n\r\n第二段\n同一段。\n  \n\n第三段。\n"
        #expect(NoticeDetailView.paragraphs(of: text) == ["第一段。", "第二段\n同一段。", "第三段。"])
    }

    @Test func linksAddressesInNoticeText() {
        let text = NoticeDetailView.linked("了解更多：www.kite.plus 或 https://explore.kite.plus/about。")
        let links = text.runs.compactMap(\.link).map(\.absoluteString)
        #expect(links == ["http://www.kite.plus", "https://explore.kite.plus/about"])
    }

    @Test func noNoticesLeavesThePosts() {
        #expect(StreamItem.items(entries: [entry("a")], notices: []).map(\.id) == ["post-a"])
    }
}

struct PreferencesTests {
    @Test func showsTheTransitionPageUntilTurnedOff() {
        let defaults = UserDefaults.standard
        let saved = defaults.object(forKey: Preferences.handoff)
        defer { defaults.set(saved, forKey: Preferences.handoff) }
        defaults.removeObject(forKey: Preferences.handoff)
        #expect(Preferences.showsHandoff)
        defaults.set(false, forKey: Preferences.handoff)
        #expect(!Preferences.showsHandoff)
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
        #expect(app.tab == .discover)
        #expect(app.takePendingRoute(for: .discover) == .topic("ai"))
    }

    @Test func opensNoticesOnDiscover() {
        let app = AppModel()
        app.open(URL(string: "https://explore.kite.plus/notices/1")!)
        #expect(app.tab == .discover)
        #expect(app.takePendingRoute(for: .discover) == .notice("1"))
    }

    @Test func opensSearchOnDiscover() {
        let app = AppModel()
        app.open(URL(string: "explore://search")!)
        #expect(app.tab == .discover)
        #expect(app.takePendingRoute(for: .discover) == .search)
    }

    @Test func opensSheetsAndTabs() {
        let app = AppModel()
        app.open(URL(string: "explore://submit")!)
        #expect(app.sheet?.id == "submit")
        app.open(URL(string: "explore://following")!)
        #expect(app.tab == .discover && app.stream == .following)
        app.open(URL(string: "https://explore.kite.plus/en/recommended")!)
        #expect(app.tab == .discover && app.stream == .recommended)
        app.open(URL(string: "https://explore.kite.plus/")!)
        #expect(app.stream == .latest)
        app.open(URL(string: "explore://nowhere")!)
        #expect(app.tab == .discover)
    }

    @Test func countsTapsOnTheCurrentDiscoverTab() {
        let app = AppModel()
        app.select(.discover)
        #expect(app.discoverRetaps == 1)
        app.select(.blogs)
        app.select(.blogs)
        #expect(app.tab == .blogs && app.discoverRetaps == 1)
        app.select(.discover)
        #expect(app.tab == .discover && app.discoverRetaps == 1)
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

struct ShareCardTests {
    private let client = APIClient(server: URL(string: "https://explore.kite.plus")!)

    @Test func postLinkIsItsSharePage() {
        let url = client.webURL(post: "12")
        #expect(url.host() == "explore.kite.plus")
        #expect(url.path().hasSuffix("/p/12"))
        #expect(url.query() == nil && url.fragment() == nil)
    }

    @Test func codeReadsBackAsTheLink() throws {
        let url = client.webURL(post: "27517")
        let code = try #require(QRCode.image(for: url)?.cgImage)
        let image = CIImage(cgImage: code).samplingNearest().transformed(by: CGAffineTransform(scaleX: 6, y: 6))
        let page = image.composited(over: CIImage(color: .white).cropped(to: image.extent.insetBy(dx: -48, dy: -48)))
        let detector = CIDetector(ofType: CIDetectorTypeQRCode, context: nil, options: [CIDetectorAccuracy: CIDetectorAccuracyHigh])
        let message = (detector?.features(in: page).first as? CIQRCodeFeature)?.messageString
        #expect(message == url.absoluteString)
    }
}
