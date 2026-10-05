import SwiftUI

/// The blog directory, most recently updated first.
@Observable
final class DirectoryModel {
    private(set) var blogs: [Blog] = []
    private(set) var nextCursor: String?
    private(set) var phase: FeedModel.Phase = .idle
    private(set) var isLoadingMore = false
    private(set) var loadMoreError: String?
    private var loadedKey: String?
    private var loadedAt: Date?

    /// Loads the directory when it is missing, belongs to another server or
    /// language, or is older than ten minutes; otherwise keeps the pages.
    func loadIfNeeded(using client: APIClient, language: LanguageFilter) async {
        if loadedKey == Self.key(client, language), phase == .loaded,
           let loadedAt, Date.now.timeIntervalSince(loadedAt) < 600 {
            return
        }
        await load(using: client, language: language)
    }

    private static func key(_ client: APIClient, _ language: LanguageFilter) -> String {
        "\(client.server.absoluteString)|\(language.rawValue)"
    }

    func load(using client: APIClient, language: LanguageFilter, fresh: Bool = false) async {
        let key = Self.key(client, language)
        if loadedKey != key {
            blogs = []
            nextCursor = nil
            phase = .loading
        }
        do {
            let page = try await client.blogs(cursor: nil, language: language.code, fresh: fresh)
            try Task.checkCancellation()
            blogs = page.data
            nextCursor = page.nextCursor
            loadedKey = key
            loadedAt = .now
            loadMoreError = nil
            phase = .loaded
        } catch {
            guard !error.isCancellation else { return }
            phase = blogs.isEmpty ? .failed(error.readableMessage) : .loaded
        }
    }

    func loadMore(using client: APIClient, language: LanguageFilter) async {
        guard let cursor = nextCursor, !isLoadingMore, phase == .loaded else { return }
        isLoadingMore = true
        loadMoreError = nil
        defer { isLoadingMore = false }
        do {
            let page = try await client.blogs(cursor: cursor, language: language.code)
            let known = Set(blogs.map(\.host))
            blogs.append(contentsOf: page.data.filter { !known.contains($0.host) })
            nextCursor = page.nextCursor
        } catch {
            guard !error.isCancellation else { return }
            loadMoreError = error.readableMessage
        }
    }
}

struct BlogsView: View {
    @Environment(AppModel.self) private var app
    @AppStorage("blogs.language") private var language: LanguageFilter = .all
    @State private var model = DirectoryModel()
    @State private var query = ""

    private var trimmed: String { query.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        ExploreStack(tab: .blogs) {
            ScrollView {
                LazyVStack(spacing: 12) {
                    if trimmed.isEmpty {
                        content
                    } else {
                        searchResults
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 32)
                .frame(maxWidth: 720)
                .frame(maxWidth: .infinity)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Blogs")
            .navigationSubtitle("Independent blogs listed on Explore")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    // The same filter button as Discover's, filled while in use.
                    let menu = Menu {
                        // Toggles rather than an inline picker, whose own
                        // section would hide this one's title.
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
                        Label("Filter", systemImage: "line.3.horizontal.decrease")
                    }
                    .menuStyle(.button)
                    .accessibilityValue(language == .all ? Text(verbatim: "") : Text("In use"))
                    if language == .all {
                        menu
                    } else {
                        menu
                            .buttonStyle(.glassProminent)
                            .buttonBorderShape(.circle)
                            .controlSize(.large)
                    }
                }
                // The filled button brings its own glass; the bar's would sit behind it.
                .sharedBackgroundVisibility(language == .all ? .automatic : .hidden)
                ToolbarSpacer(.fixed, placement: .topBarTrailing)
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        app.sheet = .submit
                    } label: {
                        Label("Submit a Blog", systemImage: "plus")
                    }
                }
            }
            .searchable(
                text: $query,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: Text("Search blogs")
            )
            .refreshable {
                await model.load(using: app.client, language: language, fresh: true)
            }
            .task(id: "\(language.rawValue)|\(app.server.absoluteString)") {
                await model.loadIfNeeded(using: app.client, language: language)
            }
            .task(id: trimmed.isEmpty) {
                if !trimmed.isEmpty {
                    await app.blogIndex.loadIfNeeded(using: app.client)
                }
            }
        }
    }

    /// Search runs over every blog, not only the pages loaded so far.
    @ViewBuilder
    private var searchResults: some View {
        let matches = app.blogIndex.matches(trimmed)
        if matches.isEmpty {
            BlogSearchEmpty(index: app.blogIndex, query: trimmed)
        } else {
            ForEach(matches) { blog in
                BlogCard(blog: blog)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch model.phase {
        case .idle, .loading:
            ForEach(0..<5, id: \.self) { _ in
                BlogPlaceholder()
            }
        case let .failed(message):
            LoadFailedView(message: message) {
                await model.load(using: app.client, language: language, fresh: true)
            }
        case .loaded:
            if model.blogs.isEmpty {
                ContentUnavailableView {
                    Label("No Blogs Yet", systemImage: "square.grid.2x2")
                } description: {
                    Text("Blogs show up here once they are listed.")
                } actions: {
                    Button("Submit a Blog") { app.sheet = .submit }
                        .buttonStyle(.primaryAction)
                }
                .padding(.vertical, 40)
            } else {
                ForEach(model.blogs) { blog in
                    BlogCard(blog: blog)
                }
                PageFooter(
                    isLoading: model.isLoadingMore,
                    error: model.loadMoreError,
                    hasMore: model.nextCursor != nil,
                    itemCount: model.blogs.count,
                    endText: "That's every listed blog"
                ) {
                    await model.loadMore(using: app.client, language: language)
                }
            }
        }
    }
}

/// A blog in the directory. The card opens the blog's page with a zoom;
/// the follow button sits above it so taps on it never open the page.
struct BlogCard: View {
    let blog: Blog

    @Environment(\.zoomNamespace) private var zoomNamespace

    private var zoomID: String { "blog-card-\(blog.host)" }

    private var contentLanguage: Locale.Language? {
        blog.language.isEmpty ? nil : Locale.Language(identifier: blog.language)
    }

    var body: some View {
        NavigationLink(value: Route.blog(blog.ref, zoomID: zoomID)) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    BlogAvatar(host: blog.host, name: blog.name, size: 48)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(blog.name)
                            .font(.headline)
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        Text(Formatting.displayHost(blog.host))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 110)
                }
                if !blog.about.isEmpty {
                    Text(blog.about)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .typesettingLanguage(contentLanguage ?? Locale.Language(identifier: "en"), isEnabled: contentLanguage != nil)
                }
                BlogFacts(blog: blog)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 24, style: .continuous))
            .contentShape(.rect(cornerRadius: 24, style: .continuous))
            .zoomSource(zoomID, in: zoomNamespace)
        }
        .buttonStyle(PressableStyle())
        .overlay(alignment: .topTrailing) {
            FollowButton(blog: blog.ref, compact: true)
                .padding(16)
        }
        .contextMenu {
            BlogActions(blog: blog.ref, feedURL: blog.feedURL)
        }
    }
}

struct BlogFacts: View {
    let blog: Blog

    var body: some View {
        HStack(spacing: 6) {
            if let language = Formatting.languageName(blog.language) {
                Pill(text: language, systemImage: "character.bubble")
            }
            if let generator = Formatting.generatorName(blog.generator) {
                Pill(text: generator, systemImage: "shippingbox")
            }
            Spacer(minLength: 0)
            if let date = blog.lastPublishedAt {
                Text("Updated \(Formatting.relative(date))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }
}

/// Follow or unfollow, in Liquid Glass: prominent until followed.
struct FollowButton: View {
    let blog: BlogRef
    var compact = false
    /// Uses plain glass even before following, beside a primary action.
    var quiet = false

    @Environment(AppModel.self) private var app

    var body: some View {
        let following = app.isFollowing(blog.host)
        Group {
            if following || quiet {
                Button(action: toggle) { label(following: following) }
                    .buttonStyle(.glass)
            } else {
                Button(action: toggle) { label(following: false) }
                    .buttonStyle(.primaryAction)
            }
        }
        .controlSize(compact ? .regular : .large)
        .disabled(app.pendingFollows.contains(blog.host))
        .sensoryFeedback(.impact(weight: .light), trigger: following)
        .animation(.bouncy, value: following)
    }

    private func label(following: Bool) -> some View {
        Label {
            // The tab is also "Following" in English, but not in Chinese.
            Text(following ? LocalizedStringResource("follow.state.following", defaultValue: "Following") : "Follow")
        } icon: {
            Image(systemName: following ? "checkmark" : "plus")
        }
        .font(compact ? .subheadline.weight(.semibold) : .body.weight(.semibold))
        .contentTransition(.symbolEffect(.replace))
    }

    private func toggle() {
        Task { await app.toggleFollow(blog) }
    }
}

/// Actions for a blog, shared by its menus.
struct BlogActions: View {
    let blog: BlogRef
    let feedURL: String?

    @Environment(AppModel.self) private var app

    var body: some View {
        if let url = URL(string: blog.siteURL) {
            Button {
                LinkOpener.open(url, source: app.sourceTag)
            } label: {
                Label("Visit Blog", systemImage: "arrow.up.forward.square")
            }
        }
        Button {
            Task { await app.toggleFollow(blog) }
        } label: {
            if app.isFollowing(blog.host) {
                Label("Unfollow", systemImage: "heart.slash")
            } else {
                Label("Follow", systemImage: "heart")
            }
        }
        if let feedURL, let url = URL(string: feedURL) {
            Section {
                Button {
                    UIPasteboard.general.url = url
                    app.showToast(String(localized: "Feed address copied"), systemImage: "doc.on.doc")
                } label: {
                    Label("Copy Feed Address", systemImage: "dot.radiowaves.up.forward")
                }
            }
        }
        Section {
            Button {
                app.sheet = .share(.blog(blog))
            } label: {
                Label("Share", systemImage: "square.and.arrow.up")
            }
            Button {
                app.sheet = app.isSignedIn ? .claim(blog) : .signIn(.signIn)
            } label: {
                Label("Claim This Blog", systemImage: "checkmark.seal")
            }
            Button(role: .destructive) {
                let target = ReportTarget(blogHost: blog.host, blogName: blog.name, entryID: nil, entryTitle: nil)
                app.sheet = app.isSignedIn ? .report(target) : .signIn(.signIn)
            } label: {
                Label("Report a Problem", systemImage: "flag")
            }
        }
    }
}

private struct BlogPlaceholder: View {
    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    Circle().frame(width: 48, height: 48)
                    VStack(alignment: .leading) {
                        Text(verbatim: "Example Blog").font(.headline)
                        Text(verbatim: "blog.example.com").font(.subheadline)
                    }
                }
                Text(verbatim: "A short description of what the blog writes about, over two lines.")
                    .font(.subheadline)
            }
        }
        .redacted(reason: .placeholder)
        .shimmering()
        .accessibilityHidden(true)
    }
}
