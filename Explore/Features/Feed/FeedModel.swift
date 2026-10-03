import SwiftUI

/// The blog languages a list can be narrowed to, as on the website.
enum LanguageFilter: String, CaseIterable, Identifiable {
    case all, zh, en

    var id: String { rawValue }

    /// The value of the API's lang parameter.
    var code: String? { self == .all ? nil : rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .all: "All"
        case .zh: "Chinese"
        case .en: "English"
        }
    }

    var symbol: String {
        switch self {
        case .all: "globe"
        case .zh: "character.book.closed.zh"
        case .en: "character.book.closed"
        }
    }
}

/// One stream of posts, paged with the server's cursor: the latest posts,
/// the recommended ones, the reader's follows, one tag, or one blog.
@Observable
final class FeedModel {
    enum Source: Hashable {
        case latest
        case recommended
        case following
        case blog(String)
    }

    enum Phase: Equatable {
        case idle, loading, loaded
        case failed(String)
    }

    let source: Source
    var language: LanguageFilter = .all
    var tag: String?
    /// Changes when what the list shows changes on the server's side, such
    /// as the account or its follows; a new version reloads the list.
    var version = 0

    private(set) var entries: [Entry] = []
    private(set) var blog: Blog?
    private(set) var nextCursor: String?
    private(set) var phase: Phase = .idle
    private(set) var isLoadingMore = false
    private(set) var loadMoreError: String?
    /// The error behind a failed first page, for callers that react to it.
    private(set) var lastError: APIError?
    private var loadedKey: String?
    private var loadedAt: Date?

    init(source: Source, tag: String? = nil) {
        self.source = source
        self.tag = tag
    }

    var hasMore: Bool { nextCursor != nil }

    var showsPlaceholders: Bool {
        (phase == .idle || phase == .loading) && entries.isEmpty
    }

    private func key(for client: APIClient) -> String {
        "\(client.server.absoluteString)|\(source)|\(language.rawValue)|\(tag ?? "")|\(version)"
    }

    /// Shows the list when a screen appears. A list already loaded for the
    /// same filters stays as it is, pages and all; after ten minutes it
    /// gains the newer posts on top.
    func refreshIfNeeded(using client: APIClient) async {
        guard loadedKey == key(for: client), phase == .loaded, !entries.isEmpty, let loadedAt else {
            await load(using: client)
            return
        }
        guard Date.now.timeIntervalSince(loadedAt) > 600 else { return }
        do {
            let page = try await fetch(client, cursor: nil, fresh: true)
            try Task.checkCancellation()
            let known = Set(entries.map(\.id))
            let newer = page.entries.prefix { !known.contains($0.id) }
            if newer.count == page.entries.count {
                // Nothing on the first page is known: start over rather
                // than leave a gap.
                entries = Self.unique(page.entries)
                nextCursor = page.next
            } else {
                entries.insert(contentsOf: newer, at: 0)
            }
            if let blog = page.blog { self.blog = blog }
            self.loadedAt = .now
        } catch {
            // The list on screen is still right for its filters.
        }
    }

    /// Loads the first page. Content for the same filters stays on screen
    /// while it refreshes; new filters start from placeholders.
    func load(using client: APIClient, fresh: Bool = false) async {
        let requestKey = key(for: client)
        if loadedKey != requestKey {
            entries = []
            blog = nil
            nextCursor = nil
            phase = .loading
        } else if entries.isEmpty {
            phase = .loading
        }
        do {
            let page = try await fetch(client, cursor: nil, fresh: fresh)
            try Task.checkCancellation()
            entries = Self.unique(page.entries)
            nextCursor = page.next
            if let blog = page.blog { self.blog = blog }
            loadedKey = requestKey
            loadedAt = .now
            loadMoreError = nil
            lastError = nil
            phase = .loaded
        } catch {
            guard !error.isCancellation else { return }
            lastError = error as? APIError
            if loadedKey == requestKey, !entries.isEmpty {
                phase = .loaded
            } else {
                phase = .failed(error.readableMessage)
            }
        }
    }

    func loadMore(using client: APIClient) async {
        guard let cursor = nextCursor, !isLoadingMore, phase == .loaded else { return }
        isLoadingMore = true
        loadMoreError = nil
        defer { isLoadingMore = false }
        do {
            let page = try await fetch(client, cursor: cursor, fresh: false)
            let known = Set(entries.map(\.id))
            entries.append(contentsOf: page.entries.filter { !known.contains($0.id) })
            nextCursor = page.next
        } catch {
            guard !error.isCancellation else { return }
            loadMoreError = error.readableMessage
        }
    }

    private struct PageResult {
        let entries: [Entry]
        let next: String?
        let blog: Blog?
    }

    private func fetch(_ client: APIClient, cursor: String?, fresh: Bool) async throws -> PageResult {
        switch source {
        case .latest:
            let page = try await client.entries(cursor: cursor, language: language.code, tag: tag, fresh: fresh)
            return PageResult(entries: page.data, next: page.nextCursor, blog: nil)
        case .recommended:
            let page = try await client.entries(cursor: cursor, language: language.code, tag: tag, order: "recommended", fresh: fresh)
            return PageResult(entries: page.data, next: page.nextCursor, blog: nil)
        case .following:
            let page = try await client.followingEntries(cursor: cursor, language: language.code, tag: tag)
            return PageResult(entries: page.data, next: page.nextCursor, blog: nil)
        case let .blog(host):
            let page = try await client.blog(host: host, cursor: cursor, fresh: fresh)
            return PageResult(entries: page.entries, next: page.nextCursor, blog: page.blog)
        }
    }

    private static func unique(_ entries: [Entry]) -> [Entry] {
        var seen = Set<String>()
        return entries.filter { seen.insert($0.id).inserted }
    }
}
