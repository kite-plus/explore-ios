import SwiftUI

/// Explore's streams in one place, as on the website: the latest posts,
/// the recommended ones and the reader's follows, as tabs over the same
/// filters. The streams sit side by side, so a swipe moves between them as
/// a tap on a tab does, and each keeps its place for when the reader comes
/// back. Search for blogs and tags sits at the top.
struct DiscoverView: View {
    @Environment(AppModel.self) private var app
    @AppStorage("discover.language") private var language: LanguageFilter = .all
    @State private var tag: String?
    @State private var latest = FeedModel(source: .latest)
    @State private var recommended = FeedModel(source: .recommended)
    @State private var following = FeedModel(source: .following)
    @State private var query = ""
    @State private var searching = false
    @State private var showsFilters = false
    @State private var page: DiscoverStream?
    /// How far the pager has scrolled, in pages: 0.5 is halfway from
    /// Latest to Recommended.
    @State private var position: CGFloat = 0
    @State private var topRequests: [DiscoverStream: Int] = [:]
    /// Whether the streams show, rather than a screen pushed over them.
    @State private var showsStreams = false

    private var filtered: Bool { language != .all || tag != nil }

    /// What the latest and recommended streams depend on.
    private var key: String { "\(language.rawValue)|\(tag ?? "")|\(app.server.absoluteString)" }

    var body: some View {
        @Bindable var app = app
        ExploreStack(tab: .discover) {
            pager
                .safeAreaBar(edge: .top) {
                    if !searching {
                        StreamBar(stream: $app.stream, position: position, filtered: filtered) {
                            showsFilters = true
                        }
                    }
                }
                .navigationTitle("Discover")
                .toolbarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        BrandTitle()
                    }
                    if app.stream == .following, app.isSignedIn {
                        ToolbarItem(placement: .topBarTrailing) {
                            NavigationLink(value: Route.subscriptions) {
                                Label("Manage", systemImage: "list.bullet")
                            }
                        }
                    }
                }
                // Search covers the streams instead of replacing them, so
                // they keep their place for when search is cancelled.
                .overlay {
                    if searching {
                        SearchContent(query: query)
                            .transition(.opacity)
                    }
                }
                .animation(.smooth(duration: 0.25), value: searching)
                .searchable(
                    text: $query, isPresented: $searching,
                    placement: .navigationBarDrawer(displayMode: .always),
                    prompt: Text("Search blogs and tags")
                )
                .sheet(isPresented: $showsFilters) {
                    FilterSheet(language: $language, tag: $tag)
                }
                .onChange(of: app.searchRequested, initial: true) {
                    if app.takeSearchRequest() {
                        searching = true
                    }
                }
        }
    }

    private var pager: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 0) {
                ForEach(DiscoverStream.allCases, id: \.self) { option in
                    stream(option)
                        .containerRelativeFrame(.horizontal)
                        .accessibilityHidden(option != app.stream)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollPosition(id: $page)
        .scrollIndicators(.hidden)
        .onScrollGeometryChange(for: CGFloat.self) { geometry in
            geometry.contentOffset.x / max(geometry.containerSize.width, 1)
        } action: { _, offset in
            position = offset
        }
        .onChange(of: page) {
            if let page, page != app.stream {
                app.stream = page
            }
        }
        .onAppear { showsStreams = true }
        .onDisappear { showsStreams = false }
        // A tap on the tab over a pushed screen only goes back to the streams.
        .onChange(of: app.discoverRetaps) {
            if showsStreams, !searching {
                topRequests[app.stream, default: 0] += 1
            }
        }
        .onChange(of: app.stream, initial: true) {
            guard page != app.stream else { return }
            if page == nil {
                page = app.stream
            } else {
                withAnimation(.snappy(duration: 0.3)) { page = app.stream }
            }
        }
    }

    @ViewBuilder
    private func stream(_ option: DiscoverStream) -> some View {
        switch option {
        case .latest:
            EntryList(feed: latest, topRequest: topRequests[.latest] ?? 0) {
                if !app.notice.isEmpty {
                    NoticeBanner(text: app.notice)
                        .padding(.top, 8)
                }
            } empty: {
                ContentUnavailableView {
                    Label(filtered ? "No Matching Posts" : "No Posts Yet", systemImage: "binoculars")
                } description: {
                    Text(filtered ? "No posts match these filters." : "Posts from listed blogs show up here.")
                }
                .padding(.vertical, 40)
            }
            .refreshable {
                await latest.load(using: app.client, fresh: true)
            }
            .task(id: key) {
                await refresh(latest)
            }
        case .recommended:
            EntryList(feed: recommended, endText: "That's every recommended post", topRequest: topRequests[.recommended] ?? 0) {
                EmptyView()
            } empty: {
                if filtered {
                    ContentUnavailableView {
                        Label("No Recommended Posts", systemImage: "sparkles")
                    } description: {
                        Text("No posts match these filters.")
                    }
                    .padding(.vertical, 40)
                } else {
                    // Nothing rated yet: the server has no model to rate posts.
                    ContentUnavailableView {
                        Label("No Recommendations Yet", systemImage: "sparkles")
                    } description: {
                        Text("No posts have been rated yet. Recommendations wait for a model to rate posts; until then, see the latest posts.")
                    } actions: {
                        Button {
                            withAnimation(.snappy) { app.stream = .latest }
                        } label: {
                            Text("See the Latest Posts")
                        }
                        .buttonStyle(.primaryAction)
                    }
                    .padding(.vertical, 40)
                }
            }
            .refreshable {
                await recommended.load(using: app.client, fresh: true)
            }
            .task(id: key) {
                await refresh(recommended)
            }
        case .following:
            FollowingStream(feed: following, language: language, tag: tag, topRequest: topRequests[.following] ?? 0)
        }
    }

    private func refresh(_ feed: FeedModel) async {
        feed.language = language
        feed.tag = tag
        await feed.refreshIfNeeded(using: app.client)
    }
}

/// The site notice maintainers set in the admin console.
struct NoticeBanner: View {
    let text: String

    @AppStorage("notice.dismissed") private var dismissed = ""

    var body: some View {
        if dismissed != text {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "megaphone.fill")
                    .foregroundStyle(Color.secondary)
                    .font(.headline)
                Text(text)
                    .font(.subheadline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button {
                    withAnimation(.snappy) { dismissed = text }
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Dismiss"))
            }
            .padding(14)
            .background(Color(.secondarySystemBackground), in: .rect(cornerRadius: 20, style: .continuous))
            .transition(.opacity.combined(with: .scale(scale: 0.95)))
        }
    }
}
