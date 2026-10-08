import Foundation
import Testing
@testable import Explore

struct RFC3339Tests {
    @Test func parsesWholeSeconds() throws {
        let date = try #require(RFC3339.date(from: "2026-09-20T02:00:00Z"))
        #expect(date == Date(timeIntervalSince1970: 1_789_869_600))
    }

    @Test func parsesMicroseconds() throws {
        // Postgres sends six fractional digits; the time must not be dropped.
        let date = try #require(RFC3339.date(from: "2026-10-02T14:17:01.729921Z"))
        let whole = try #require(RFC3339.date(from: "2026-10-02T14:17:01Z"))
        #expect(abs(date.timeIntervalSince(whole) - 0.729921) < 0.000_01)
    }

    @Test func parsesOffsets() throws {
        let utc = try #require(RFC3339.date(from: "2026-09-20T02:00:00Z"))
        let shanghai = try #require(RFC3339.date(from: "2026-09-20T10:00:00+08:00"))
        #expect(utc == shanghai)
    }

    @Test(arguments: ["", "yesterday", "2026-13-45T99:00:00Z"])
    func rejectsGarbage(_ text: String) {
        #expect(RFC3339.date(from: text) == nil)
    }
}

struct DecodingTests {
    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = RFC3339.decoding
        return decoder
    }()

    @Test func entriesPage() throws {
        let json = """
        {"data":[{"id":"12","title":"Hello","url":"https://blog.example.com/posts/hello/",
        "excerpt":"First paragraph","image_url":"/api/v1/entries/12/image",
        "published_at":"2026-08-29T18:02:33Z","tags":["backend","ops"],"link_status":"available",
        "link_checked_at":"2026-10-02T14:17:01.729921Z",
        "blog":{"host":"blog.example.com","name":"Example Blog","site_url":"https://blog.example.com/","language":"zh-Hans"}}],
        "next_cursor":"MTc4NTcyNDkxMjAwMDAwMDAwMDoxMw"}
        """
        let page = try decoder.decode(Page<Entry>.self, from: Data(json.utf8))
        let entry = try #require(page.data.first)
        #expect(entry.id == "12")
        #expect(entry.imagePath == "/api/v1/entries/12/image")
        #expect(entry.tags == ["backend", "ops"])
        #expect(entry.linkStatus == .available)
        #expect(entry.linkCheckedAt != nil)
        #expect(entry.blog?.language == "zh-Hans")
        #expect(page.nextCursor == "MTc4NTcyNDkxMjAwMDAwMDAwMDoxMw")
    }

    @Test func notices() throws {
        let json = """
        {"data": [
          {"id": "7", "kind": "notice", "title": "Kite for iOS", "summary": "", "url": "", "source_name": "Kite Plus", "position": 0, "published_at": "2026-10-06T00:00:00Z"},
          {"id": "8", "kind": "sponsored", "title": "Hosting", "summary": "Cheap.", "url": "https://ads.example.com/", "source_name": "Acme", "position": 4, "published_at": "2026-10-06T00:00:00Z"}
        ]}
        """
        let list = try decoder.decode(DataList<Notice>.self, from: Data(json.utf8))
        #expect(list.data.map(\.id) == ["7", "8"])
        #expect(list.data[0].isNotice && list.data[0].isPinned)
        // A kind the app does not know shows as an ad, never unmarked.
        #expect(!list.data[1].isNotice && !list.data[1].isPinned)
        #expect(list.data[1].sourceName == "Acme")
        #expect(list.data[0].body == nil)

        let one = try decoder.decode(Notice.self, from: Data(#"{"id": "7", "kind": "notice", "title": "x", "summary": "", "url": "", "source_name": "Kite Plus", "position": 0, "published_at": "2026-10-06T00:00:00Z", "body": "a\n\nb"}"#.utf8))
        #expect(one.body == "a\n\nb")
    }

    @Test func entryWithoutExcerptOrBlog() throws {
        // A blog page's posts carry no blog, and authors may hide excerpts.
        let json = """
        {"id":"8","title":"Untitled","url":"https://example.com/a","excerpt":null,"image_url":null,
        "published_at":null,"link_status":"something-new","link_checked_at":null}
        """
        let entry = try decoder.decode(Entry.self, from: Data(json.utf8))
        #expect(entry.excerpt == nil)
        #expect(entry.imagePath == nil)
        #expect(entry.publishedAt == nil)
        #expect(entry.tags.isEmpty)
        #expect(entry.linkStatus == .unknown)
        #expect(entry.blog == nil)
    }

    @Test func blogPage() throws {
        let json = """
        {"blog":{"host":"www.amigoer.com","name":"Amigoer's Blog","description":"","site_url":"https://www.amigoer.com/",
        "feed_url":"https://www.amigoer.com/rss.xml","language":"zh-CN","generator":"unknown","last_published_at":null},
        "entries":[],"next_cursor":null}
        """
        let page = try decoder.decode(BlogPage.self, from: Data(json.utf8))
        #expect(page.blog.host == "www.amigoer.com")
        #expect(page.blog.about.isEmpty)
        #expect(page.blog.lastPublishedAt == nil)
        #expect(page.blog.ref.siteURL == "https://www.amigoer.com/")
        #expect(page.nextCursor == nil)
    }

    @Test func topics() throws {
        let json = #"{"data":[{"slug":"frontend","name":{"zh":"前端","en":"Frontend"}}]}"#
        let list = try decoder.decode(DataList<Topic>.self, from: Data(json.utf8))
        let topic = try #require(list.data.first)
        #expect(topic.name(in: .zh) == "前端")
        #expect(topic.name(in: .en) == "Frontend")
    }

    @Test func user() throws {
        let json = #"{"id":"9f1","email":"a@example.com","display_name":"A","is_admin":false,"csrf_token":"abc"}"#
        let user = try decoder.decode(User.self, from: Data(json.utf8))
        #expect(user.displayName == "A")
        #expect(user.csrfToken == "abc")
        #expect(user.temporaryPassword == nil)
    }

    @Test func userWithTemporaryPassword() throws {
        let json = """
        {"id":"9f1","email":"a@example.com","display_name":"A","is_admin":false,"csrf_token":"abc",
        "temporary_password":true}
        """
        let user = try decoder.decode(User.self, from: Data(json.utf8))
        #expect(user.temporaryPassword == true)
    }

    @Test func opmlImport() throws {
        let json = """
        {"outlines":4,"added":2,"already_following":1,"ignored":0,
        "not_listed":[{"title":"Elsewhere","site_url":"","feed_url":"https://elsewhere.example/feed.xml"}]}
        """
        let result = try decoder.decode(OPMLImport.self, from: Data(json.utf8))
        #expect(result.outlines == 4)
        #expect(result.alreadyFollowing == 1)
        #expect(result.notListed.first?.feedURL == "https://elsewhere.example/feed.xml")
        #expect(result.notListed.first?.siteURL == "")
    }

    @Test func submission() throws {
        let json = """
        {"id":"0f6b","status":"pending","host":"blog.example.com","site_url":"https://blog.example.com/",
        "feed_url":"https://blog.example.com/atom.xml",
        "check_report":{"input_url":"https://blog.example.com/","passed":true,"problems":[
          {"code":"no_conditional_get","severity":"info","hint":"No ETag."}],
          "items":{"total":20,"valid":19,"trusted_dates":19,"latest_published_at":"2026-09-14T04:30:00Z"}},
        "created_at":"2026-09-20T02:00:00.5Z","reviewed_at":null}
        """
        let submission = try decoder.decode(Submission.self, from: Data(json.utf8))
        #expect(submission.status == .pending)
        #expect(submission.checkReport?.problems.first?.severity == .info)
        #expect(submission.checkReport?.items?.valid == 19)
        #expect(submission.reviewNote == nil)
    }

    @Test func checkFailedError() {
        let json = """
        {"error":{"code":"check_failed","message":"The blog did not pass the check."},
        "check_report":{"input_url":"https://x.example/","passed":false,"problems":[{"code":"feed_not_found","severity":"error"}]}}
        """
        let error = APIError(status: 422, data: Data(json.utf8), decoder: decoder)
        #expect(error.code == "check_failed")
        #expect(error.report?.problems.first?.code == "feed_not_found")
        #expect(error.readableMessage == "The blog did not pass the check.")
    }

    @Test func pendingErrorCarriesSubmission() {
        let json = #"{"error":{"code":"already_pending","message":"Waiting."},"submission_id":"abc"}"#
        let error = APIError(status: 409, data: Data(json.utf8), decoder: decoder)
        #expect(error.submissionID == "abc")
    }

    @Test func proxyErrorsStillMapToCodes() {
        let html = Data("<html>Bad gateway</html>".utf8)
        #expect(APIError(status: 502, data: html, decoder: decoder).code == "internal")
        #expect(APIError(status: 429, data: Data(), decoder: decoder).code == "rate_limited")
        #expect(APIError(status: 401, data: Data(), decoder: decoder).isUnauthorized)
    }
}
