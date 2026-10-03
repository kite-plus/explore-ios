import Foundation
import Observation

/// The whole blog list, kept on the device so search answers as you type.
/// Explore has no search endpoint; its directory is small enough to hold.
@Observable
final class BlogIndex {
    private(set) var blogs: [Blog] = []
    private(set) var isLoading = false
    private(set) var error: String?
    private var loadedServer: URL?

    func loadIfNeeded(using client: APIClient) async {
        guard loadedServer != client.server, !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        var all: [Blog] = []
        var cursor: String?
        do {
            repeat {
                let page = try await client.blogs(cursor: cursor, language: nil, limit: 100)
                all.append(contentsOf: page.data)
                cursor = page.nextCursor
            } while cursor != nil && all.count < 3000
            blogs = all
            loadedServer = client.server
            error = nil
        } catch {
            guard !error.isCancellation else { return }
            self.error = error.readableMessage
        }
    }

    func matches(_ query: String) -> [Blog] {
        let terms = query.split(whereSeparator: \.isWhitespace).map(String.init)
        guard !terms.isEmpty else { return [] }
        return blogs.filter { blog in
            terms.allSatisfy { term in
                blog.name.localizedStandardContains(term)
                    || blog.host.localizedStandardContains(term)
                    || blog.about.localizedStandardContains(term)
            }
        }
    }
}
