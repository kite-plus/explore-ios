import SwiftUI

/// A scrolling column of post cards with placeholders, errors, an empty
/// state and paging. The header scrolls with the posts.
struct EntryList<Header: View, Pinned: View, Empty: View>: View {
    let feed: FeedModel
    var showsBlog = true
    var contextBlog: BlogRef?
    var endText: LocalizedStringKey? = "You're all caught up"
    var onScroll: ((CGFloat) -> Void)?
    @ViewBuilder var header: Header
    /// Stays under the navigation bar while the posts scroll beneath it.
    @ViewBuilder var pinned: Pinned
    @ViewBuilder var empty: Empty

    @Environment(AppModel.self) private var app

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12, pinnedViews: [.sectionHeaders]) {
                header
                    .padding(.horizontal, 16)
                    .frame(maxWidth: 720)
                    .frame(maxWidth: .infinity)
                Section {
                    content
                } header: {
                    pinned
                }
            }
            .padding(.top, 4)
            .padding(.bottom, 32)
        }
        .scrollDismissesKeyboard(.immediately)
        .onScrollGeometryChange(for: CGFloat.self) { geometry in
            geometry.contentOffset.y + geometry.contentInsets.top
        } action: { _, offset in
            onScroll?(offset)
        }
        .background(Color(.systemGroupedBackground))
    }

    @ViewBuilder
    private var content: some View {
        Group {
            rows
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: 720)
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var rows: some View {
        if feed.showsPlaceholders {
            ForEach(0..<4, id: \.self) { _ in
                EntryPlaceholder()
            }
        } else if case let .failed(message) = feed.phase {
            LoadFailedView(message: message) {
                await feed.load(using: app.client, fresh: true)
            }
        } else if feed.entries.isEmpty {
            empty
        } else {
            ForEach(feed.entries) { entry in
                EntryCard(entry: entry, showsBlog: showsBlog, contextBlog: contextBlog ?? feed.blog?.ref)
                    .transition(.opacity)
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

extension EntryList where Pinned == EmptyView {
    init(
        feed: FeedModel, showsBlog: Bool = true, contextBlog: BlogRef? = nil,
        endText: LocalizedStringKey? = "You're all caught up", onScroll: ((CGFloat) -> Void)? = nil,
        @ViewBuilder header: () -> Header, @ViewBuilder empty: () -> Empty
    ) {
        self.init(
            feed: feed, showsBlog: showsBlog, contextBlog: contextBlog, endText: endText, onScroll: onScroll,
            header: header, pinned: { EmptyView() }, empty: empty
        )
    }
}
