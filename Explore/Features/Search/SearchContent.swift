import SwiftUI

/// What the search field shows: tags and recently updated blogs before
/// typing; after, the tags that match on the device and the blogs and
/// posts the server finds, posts paged as the list scrolls.
struct SearchContent: View {
    let query: String

    @Environment(AppModel.self) private var app
    @AppStorage("search.language") private var language: LanguageFilter = .all
    @State private var model = SearchModel()
    @State private var recent: [Blog] = []
    @State private var position = ScrollPosition(edge: .top)

    private var trimmed: String { query.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var searchQuery: SearchModel.Query { SearchModel.Query(text: trimmed, language: language.code) }
    /// True from a keystroke until the results for it arrive.
    private var isPending: Bool { model.query != searchQuery }

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
        .scrollPosition($position)
        .onChange(of: model.query) {
            position.scrollTo(edge: .top)
        }
        .scrollDismissesKeyboard(.immediately)
        .background(Color(.systemGroupedBackground))
        .task(id: app.server.absoluteString) {
            async let topics: Void = app.loadTopics()
            if let page = try? await app.client.blogs(cursor: nil, language: nil, limit: 6) {
                recent = page.data
            }
            await topics
        }
        .task(id: [trimmed, language.rawValue, app.server.absoluteString]) {
            guard !trimmed.isEmpty else {
                model.reset()
                return
            }
            // Waits for a pause in typing; the next keystroke cancels this.
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            await model.search(searchQuery, using: app.client)
            if model.phase == .unsupported {
                await app.blogIndex.loadIfNeeded(using: app.client)
            }
        }
    }

    @ViewBuilder
    private var browse: some View {
        SectionTitle("Browse Tags")
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
        if !recent.isEmpty {
            SectionTitle("Recently Updated")
                .padding(.top, 12)
            ForEach(recent) { blog in
                BlogRow(blog: blog)
            }
        }
    }

    private var topics: [Topic] {
        app.topics.filter { topic in
            topic.name.values.contains { $0.localizedStandardContains(trimmed) } || topic.slug.localizedStandardContains(trimmed)
        }
    }

    @ViewBuilder
    private var results: some View {
        let topics = topics
        switch model.phase {
        case .unsupported:
            deviceResults(topics: topics)
        case let .failed(message):
            summary
            tagSection(topics)
            LoadFailedView(message: message) {
                await model.search(searchQuery, using: app.client)
            }
        default:
            summary
            if !isPending, model.isEmpty, topics.isEmpty {
                ContentUnavailableView.search(text: trimmed)
                    .padding(.vertical, 40)
            } else {
                let words = SearchTerms.words(in: model.query?.text ?? trimmed)
                tagSection(topics)
                if !model.blogs.isEmpty {
                    SectionTitle("Blogs")
                    blogStrip(words: words)
                }
                if !model.entries.isEmpty || isPending {
                    SectionTitle("Posts")
                    posts(words: words)
                }
            }
        }
    }

    /// The counts for the results on screen and the language they cover.
    private var summary: some View {
        HStack(spacing: 8) {
            if model.query != nil, !isFailed {
                HStack(spacing: 4) {
                    Text(model.entryCountCapped ? "\(model.entryCount)+ posts" : "\(model.entryCount) posts")
                    Text(verbatim: "·")
                        .accessibilityHidden(true)
                    Text("\(model.blogCount) blogs")
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .contentTransition(.numericText())
            }
            if isPending, !isFailed {
                ProgressView()
                    .controlSize(.small)
            }
            Spacer(minLength: 0)
            languageMenu
        }
        .frame(minHeight: 32)
    }

    private var isFailed: Bool {
        if case .failed = model.phase { true } else { false }
    }

    private var languageMenu: some View {
        let menu = Menu {
            Section("Blog language") {
                ForEach(LanguageFilter.allCases) { option in
                    Toggle(isOn: Binding {
                        language == option
                    } set: { isOn in
                        if isOn { language = option }
                    }) {
                        Label(option.title, systemImage: option.symbol)
                    }
                }
            }
        } label: {
            Label(language.title, systemImage: language.symbol)
                .font(.subheadline.weight(.medium))
        }
        .menuStyle(.button)
        .buttonBorderShape(.capsule)
        .controlSize(.small)
        .accessibilityLabel(Text("Blog language"))
        .accessibilityValue(Text(language.title))
        return Group {
            if language == .all {
                menu.buttonStyle(.bordered)
            } else {
                menu.buttonStyle(.borderedProminent)
            }
        }
    }

    @ViewBuilder
    private func tagSection(_ topics: [Topic]) -> some View {
        if !topics.isEmpty {
            SectionTitle("Tags")
            FlowLayout(spacing: 8, lineSpacing: 8) {
                ForEach(topics) { topic in
                    TopicChip(topic: topic)
                }
            }
        }
    }

    /// Blogs in a row that pages sideways, so the posts stay in view.
    private func blogStrip(words: [String]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 12) {
                ForEach(model.blogs) { blog in
                    BlogResultCard(blog: blog, highlight: words)
                }
                if model.blogCursor != nil {
                    BlogStripFooter(model: model)
                }
            }
            .padding(.horizontal, 16)
        }
        // New results start at the first blog; an offset kept from the last
        // ones would show the footer at once and page through them all.
        .id(model.query)
        .padding(.horizontal, -16)
    }

    private func posts(words: [String]) -> some View {
        LazyVStack(alignment: .leading, spacing: 0) {
            if model.entries.isEmpty {
                ForEach(0..<3, id: \.self) { index in
                    EntryPlaceholder()
                    if index < 2 { Divider() }
                }
            } else {
                ForEach(model.entries) { entry in
                    VStack(spacing: 0) {
                        EntryRow(entry: entry, highlight: words)
                        if entry.id != model.entries.last?.id {
                            Divider()
                        }
                    }
                }
                if model.entryCursor != nil {
                    PageFooter(
                        isLoading: model.isLoadingMoreEntries,
                        error: model.entryPageError,
                        hasMore: true,
                        itemCount: model.entries.count,
                        endText: nil
                    ) {
                        await model.loadMoreEntries(using: app.client)
                    }
                }
            }
        }
        .padding(.horizontal, 14)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 22, style: .continuous))
    }

    /// A server from before search: tags, and blogs matched on the device.
    @ViewBuilder
    private func deviceResults(topics: [Topic]) -> some View {
        let index = app.blogIndex
        let blogs = index.matches(trimmed)
        Text("This server can't search posts yet.")
            .font(.subheadline)
            .foregroundStyle(.secondary)
        if topics.isEmpty && blogs.isEmpty {
            BlogSearchEmpty(index: index, query: trimmed)
        } else {
            tagSection(topics)
            if !blogs.isEmpty {
                SectionTitle("Blogs")
                ForEach(blogs) { blog in
                    BlogRow(blog: blog)
                }
            }
        }
    }
}

/// Loads the strip's next blogs once it scrolls into view, or offers a retry.
private struct BlogStripFooter: View {
    let model: SearchModel

    @Environment(AppModel.self) private var app

    var body: some View {
        ZStack {
            if model.blogPageError != nil {
                Button {
                    Task { await model.loadMoreBlogs(using: app.client) }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.circle)
                .accessibilityLabel(Text("Try Again"))
            } else {
                ProgressView()
            }
        }
        .frame(width: 56)
        .task(id: model.blogs.count) {
            guard model.blogPageError == nil else { return }
            await model.loadMoreBlogs(using: app.client)
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

/// A tile for a topic; it zooms into the topic's posts.
struct TopicTile: View {
    let topic: Topic

    @Environment(\.zoomNamespace) private var zoomNamespace

    private var zoomID: String { "topic-tile-\(topic.slug)" }

    var body: some View {
        NavigationLink(value: Route.topic(topic.slug, zoomID: zoomID)) {
            ZStack(alignment: .topLeading) {
                Color(.secondarySystemGroupedBackground)
                Image(systemName: TopicStyle.symbol(for: topic.slug))
                    .font(.system(size: 50, weight: .semibold))
                    .foregroundStyle(Color(.quaternaryLabel))
                    .rotationEffect(.degrees(-12))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .offset(x: 10, y: 12)
                Text(topic.name(in: .current))
                    .font(.headline)
                    .foregroundStyle(Color.primary)
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

/// A tag that matched a search, as a small capsule leading to its posts.
struct TopicChip: View {
    let topic: Topic

    var body: some View {
        NavigationLink(value: Route.topic(topic.slug)) {
            Label(topic.name(in: .current), systemImage: TopicStyle.symbol(for: topic.slug))
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color(.secondarySystemGroupedBackground), in: .capsule)
                .contentShape(.capsule)
        }
        .buttonStyle(PressableStyle())
    }
}

/// A blog a search found, sized to sit in a row of them.
struct BlogResultCard: View {
    let blog: Blog
    var highlight: [String] = []

    @ScaledMetric(relativeTo: .body) private var height: CGFloat = 112

    private var contentLanguage: Locale.Language? {
        blog.language.isEmpty ? nil : Locale.Language(identifier: blog.language)
    }

    var body: some View {
        NavigationLink(value: Route.blog(blog.ref)) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    BlogAvatar(host: blog.host, name: blog.name, size: 36)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(SearchTerms.marked(blog.name, words: highlight))
                            .font(.headline)
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        Text(Formatting.displayHost(blog.host))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                if !blog.about.isEmpty {
                    Text(SearchTerms.marked(SearchTerms.snippet(blog.about, words: highlight), words: highlight))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .typesettingLanguage(contentLanguage ?? Locale.Language(identifier: "en"), isEnabled: contentLanguage != nil)
                }
            }
            .padding(14)
            .frame(width: 248, height: height, alignment: .topLeading)
            .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 20, style: .continuous))
            .contentShape(.rect(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(PressableStyle())
        .contextMenu {
            BlogActions(blog: blog.ref, feedURL: blog.feedURL)
        }
    }
}
