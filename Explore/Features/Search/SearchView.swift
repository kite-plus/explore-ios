import SwiftUI

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

struct SearchView: View {
    @Environment(AppModel.self) private var app
    @State private var index = BlogIndex()
    @State private var query = ""

    private var trimmed: String { query.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        ExploreStack(tab: .search) {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if trimmed.isEmpty {
                        browse
                    } else {
                        results
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 32)
                .frame(maxWidth: 720)
                .frame(maxWidth: .infinity)
                .animation(.smooth, value: trimmed.isEmpty)
            }
            .scrollDismissesKeyboard(.immediately)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Search")
            .searchable(text: $query, prompt: Text("Blogs and topics"))
            .task(id: app.server.absoluteString) {
                await index.loadIfNeeded(using: app.client)
                await app.loadTopics()
            }
        }
    }

    @ViewBuilder
    private var browse: some View {
        SectionTitle("Browse Topics")
        if app.topics.isEmpty {
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
        } else {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 156), spacing: 12)], spacing: 12) {
                ForEach(app.topics) { topic in
                    TopicTile(topic: topic)
                }
            }
        }
        if !index.blogs.isEmpty {
            SectionTitle("Recently Updated")
                .padding(.top, 12)
            ForEach(index.blogs.prefix(6)) { blog in
                BlogRow(blog: blog)
            }
        }
    }

    @ViewBuilder
    private var results: some View {
        let topics = app.topics.filter { topic in
            topic.name.values.contains { $0.localizedStandardContains(trimmed) } || topic.slug.localizedStandardContains(trimmed)
        }
        let blogs = index.matches(trimmed)
        if topics.isEmpty && blogs.isEmpty {
            if index.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
            } else {
                ContentUnavailableView.search(text: trimmed)
                    .padding(.vertical, 40)
            }
        } else {
            if !topics.isEmpty {
                SectionTitle("Topics")
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 156), spacing: 12)], spacing: 12) {
                    ForEach(topics) { topic in
                        TopicTile(topic: topic)
                    }
                }
            }
            if !blogs.isEmpty {
                SectionTitle("Blogs")
                    .padding(.top, topics.isEmpty ? 0 : 12)
                ForEach(blogs) { blog in
                    BlogRow(blog: blog)
                }
            }
        }
    }
}

struct SectionTitle: View {
    let title: LocalizedStringKey

    init(_ title: LocalizedStringKey) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .font(.title3.bold())
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 8)
            .accessibilityAddTraits(.isHeader)
    }
}

/// A colorful tile for a topic; it zooms into the topic's posts.
struct TopicTile: View {
    let topic: Topic

    @Environment(\.zoomNamespace) private var zoomNamespace

    private var zoomID: String { "topic-tile-\(topic.slug)" }

    var body: some View {
        let style = TopicStyle.of(topic.slug)
        NavigationLink(value: Route.topic(topic.slug, zoomID: zoomID)) {
            ZStack(alignment: .topLeading) {
                style.gradient
                Image(systemName: style.symbol)
                    .font(.system(size: 50, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.3))
                    .rotationEffect(.degrees(-12))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .offset(x: 10, y: 12)
                Text(topic.name(in: .current))
                    .font(.headline)
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.15), radius: 2, y: 1)
                    .padding(14)
            }
            .frame(height: 92)
            .clipShape(.rect(cornerRadius: 22, style: .continuous))
            .contentShape(.rect(cornerRadius: 22, style: .continuous))
            .zoomSource(zoomID, in: zoomNamespace)
        }
        .buttonStyle(PressableStyle())
    }
}

struct BlogRow: View {
    let blog: Blog

    var body: some View {
        NavigationLink(value: Route.blog(blog.ref)) {
            HStack(spacing: 12) {
                BlogAvatar(host: blog.host, name: blog.name, size: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text(blog.name)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text(blog.about.isEmpty ? Formatting.displayHost(blog.host) : blog.about)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(12)
            .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 20, style: .continuous))
            .contentShape(.rect(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(PressableStyle())
    }
}
