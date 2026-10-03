import SwiftUI

/// What the search field shows: topics and recently updated blogs before
/// typing, matching topics and blogs after.
struct SearchContent: View {
    let query: String

    @Environment(AppModel.self) private var app

    private var trimmed: String { query.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
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
        .task(id: app.server.absoluteString) {
            await app.blogIndex.loadIfNeeded(using: app.client)
            await app.loadTopics()
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
        if !app.blogIndex.blogs.isEmpty {
            SectionTitle("Recently Updated")
                .padding(.top, 12)
            ForEach(app.blogIndex.blogs.prefix(6)) { blog in
                BlogRow(blog: blog)
            }
        }
    }

    @ViewBuilder
    private var results: some View {
        let index = app.blogIndex
        let topics = app.topics.filter { topic in
            topic.name.values.contains { $0.localizedStandardContains(trimmed) } || topic.slug.localizedStandardContains(trimmed)
        }
        let blogs = index.matches(trimmed)
        if topics.isEmpty && blogs.isEmpty {
            BlogSearchEmpty(index: index, query: trimmed)
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

/// Shown when a search finds nothing: still loading, failed, or no match.
struct BlogSearchEmpty: View {
    let index: BlogIndex
    let query: String

    @Environment(AppModel.self) private var app

    var body: some View {
        if index.isLoading {
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
        } else if index.blogs.isEmpty, let error = index.error {
            LoadFailedView(message: error) {
                await index.loadIfNeeded(using: app.client)
            }
        } else {
            ContentUnavailableView.search(text: query)
                .padding(.vertical, 40)
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
