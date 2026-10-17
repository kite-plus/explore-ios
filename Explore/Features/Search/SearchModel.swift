import Foundation
import Observation

/// One search on the server: the posts and the blogs that match a query,
/// each paged with its own cursor.
@Observable
final class SearchModel {
    enum Phase: Equatable {
        case idle, loading, loaded
        case failed(String)
        /// The server predates search; blogs are matched on the device.
        case unsupported
    }

    struct Query: Hashable {
        var text: String
        var language: String?
    }

    static let entryPageSize = 30

    /// False for blogs alone, as the Blogs tab searches.
    let includesPosts: Bool
    let blogPageSize: Int

    /// What the results on screen answer, which lags the field while a
    /// new search runs.
    private(set) var query: Query?
    private(set) var entries: [Entry] = []
    private(set) var blogs: [Blog] = []
    /// How many posts match, counted up to 1,000; see entryCountCapped.
    private(set) var entryCount = 0
    private(set) var entryCountCapped = false
    private(set) var blogCount = 0
    private(set) var entryCursor: String?
    private(set) var blogCursor: String?
    private(set) var phase: Phase = .idle
    private(set) var isLoadingMoreEntries = false
    private(set) var isLoadingMoreBlogs = false
    private(set) var entryPageError: String?
    private(set) var blogPageError: String?
    private var server: URL?
    /// A server that answered 404, so it is not asked again.
    private var serverWithoutSearch: URL?

    var isEmpty: Bool { entries.isEmpty && blogs.isEmpty }

    init(includesPosts: Bool = true) {
        self.includesPosts = includesPosts
        blogPageSize = includesPosts ? 10 : 30
    }

    /// Runs a search. The results on screen stay until the new ones come,
    /// so typing does not flash placeholders.
    func search(_ query: Query, using client: APIClient) async {
        if serverWithoutSearch == client.server {
            show(query, from: client)
            phase = .unsupported
            return
        }
        if self.query == query, server == client.server, phase == .loaded { return }
        if server != client.server { clear() }
        phase = .loading
        do {
            async let foundBlogs = client.searchBlogs(
                query.text, cursor: nil, language: query.language, limit: blogPageSize
            )
            let entryPage = includesPosts
                ? try await client.searchEntries(query.text, cursor: nil, language: query.language, limit: Self.entryPageSize)
                : nil
            let blogPage = try await foundBlogs
            try Task.checkCancellation()
            show(query, from: client)
            entries = Self.unique(entryPage?.data ?? [], by: \.id)
            blogs = Self.unique(blogPage.data, by: \.host)
            entryCount = entryPage?.total ?? entries.count
            entryCountCapped = entryPage?.totalCapped ?? false
            blogCount = blogPage.total ?? blogs.count
            entryCursor = entryPage?.nextCursor
            blogCursor = blogPage.nextCursor
            phase = .loaded
        } catch let error as APIError where error.status == 404 {
            serverWithoutSearch = client.server
            show(query, from: client)
            phase = .unsupported
        } catch {
            guard !error.isCancellation else { return }
            phase = .failed(error.readableMessage)
        }
    }

    /// Forgets the results once the field is empty, so the next search
    /// does not open on the last one's.
    func reset() {
        clear()
        if phase != .unsupported { phase = .idle }
    }

    func loadMoreEntries(using client: APIClient) async {
        guard let query, let cursor = entryCursor, !isLoadingMoreEntries, phase == .loaded else { return }
        isLoadingMoreEntries = true
        entryPageError = nil
        defer { isLoadingMoreEntries = false }
        do {
            let page = try await client.searchEntries(
                query.text, cursor: cursor, language: query.language, limit: Self.entryPageSize
            )
            guard self.query == query else { return }
            entries = Self.unique(entries + page.data, by: \.id)
            entryCursor = page.nextCursor
        } catch {
            guard !error.isCancellation, self.query == query else { return }
            entryPageError = error.readableMessage
        }
    }

    func loadMoreBlogs(using client: APIClient) async {
        guard let query, let cursor = blogCursor, !isLoadingMoreBlogs, phase == .loaded else { return }
        isLoadingMoreBlogs = true
        blogPageError = nil
        defer { isLoadingMoreBlogs = false }
        do {
            let page = try await client.searchBlogs(
                query.text, cursor: cursor, language: query.language, limit: blogPageSize
            )
            guard self.query == query else { return }
            blogs = Self.unique(blogs + page.data, by: \.host)
            blogCursor = page.nextCursor
        } catch {
            guard !error.isCancellation, self.query == query else { return }
            blogPageError = error.readableMessage
        }
    }

    private func show(_ query: Query, from client: APIClient) {
        clear()
        self.query = query
        server = client.server
    }

    private func clear() {
        query = nil
        entries = []
        blogs = []
        entryCount = 0
        entryCountCapped = false
        blogCount = 0
        entryCursor = nil
        blogCursor = nil
        entryPageError = nil
        blogPageError = nil
    }

    private static func unique<Item, Key: Hashable>(_ items: [Item], by key: KeyPath<Item, Key>) -> [Item] {
        var seen = Set<Key>()
        return items.filter { seen.insert($0[keyPath: key]).inserted }
    }
}
