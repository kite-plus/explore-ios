import SwiftUI

/// A stream of posts in one run, newest first, as flat rows split by
/// hairlines; each row says when its post came out. It brings placeholders,
/// errors, an empty state and paging; the header scrolls with the posts.
struct EntryList<Header: View, Empty: View>: View {
    let feed: FeedModel
    var showsBlog = true
    var contextBlog: BlogRef?
    var endText: LocalizedStringKey? = "You're all caught up"
    var onScroll: ((CGFloat) -> Void)?
    /// Scrolls the list back to the top whenever it changes.
    var topRequest = 0
    @ViewBuilder var header: Header
    @ViewBuilder var empty: Empty

    @Environment(AppModel.self) private var app
    @State private var position = ScrollPosition(edge: .top)

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                header
                rows
            }
            .padding(.horizontal, 16)
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
            .padding(.bottom, 32)
        }
        .scrollPosition($position)
        .scrollDismissesKeyboard(.immediately)
        .onChange(of: topRequest) {
            withAnimation(.smooth) { position.scrollTo(edge: .top) }
        }
        .onScrollGeometryChange(for: CGFloat.self) { geometry in
            geometry.contentOffset.y + geometry.contentInsets.top
        } action: { _, offset in
            onScroll?(offset)
        }
        .background(Color(.systemBackground))
    }

    @ViewBuilder
    private var rows: some View {
        if feed.showsPlaceholders {
            ForEach(0..<4, id: \.self) { index in
                EntryPlaceholder()
                if index < 3 { Divider() }
            }
        } else if case let .failed(message) = feed.phase {
            LoadFailedView(message: message) {
                await feed.load(using: app.client, fresh: true)
            }
        } else if feed.entries.isEmpty {
            empty
        } else {
            ForEach(feed.entries) { entry in
                VStack(spacing: 0) {
                    EntryRow(entry: entry, showsBlog: showsBlog, contextBlog: contextBlog ?? feed.blog?.ref)
                    if entry.id != feed.entries.last?.id {
                        Divider()
                    }
                }
            }
            PageFooter(
                isLoading: feed.isLoadingMore,
                error: feed.loadMoreError,
                hasMore: feed.hasMore,
                itemCount: feed.entries.count,
                endText: endText
            ) {
                await feed.loadMore(using: app.client)
            }
        }
    }
}
