import SwiftUI

/// A stream of posts under the days they came out on, as the website lists
/// them: a heading for each day, then flat rows split by hairlines. It
/// brings placeholders, errors, an empty state and paging; the header
/// scrolls with the posts.
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
            // One flat run of headings and rows: a lazy stack handles that
            // better than a list nested in a list.
            ForEach(ListItem.items(DayGroup.groups(of: feed.entries), now: .now)) { item in
                switch item {
                case let .heading(group, first, now):
                    DayHeading(group: group, now: now, first: first)
                case let .entry(entry, clockTime, last):
                    VStack(spacing: 0) {
                        EntryRow(
                            entry: entry, showsBlog: showsBlog, contextBlog: contextBlog ?? feed.blog?.ref,
                            clockTime: clockTime
                        )
                        if !last {
                            Divider()
                        }
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

/// A day's heading or one of its posts, in the order the list shows them.
private enum ListItem: Identifiable {
    case heading(DayGroup, first: Bool, now: Date)
    case entry(Entry, clockTime: Bool, last: Bool)

    var id: String {
        switch self {
        case let .heading(group, _, _): "day-\(group.id)"
        case let .entry(entry, _, _): "post-\(entry.id)"
        }
    }

    static func items(_ groups: [DayGroup], now: Date) -> [ListItem] {
        groups.enumerated().flatMap { index, group in
            let clockTime = group.showsClockTime(now: now)
            return [ListItem.heading(group, first: index == 0, now: now)] + group.entries.map { entry in
                ListItem.entry(entry, clockTime: clockTime, last: entry.id == group.entries.last?.id)
            }
        }
    }
}

/// "Today" or "Yesterday" with the date beside it, or the date alone.
private struct DayHeading: View {
    let group: DayGroup
    let now: Date
    let first: Bool

    var body: some View {
        let heading = group.heading(now: now)
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(heading.name)
                .font(.headline)
            if let date = heading.date {
                Text(date)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.top, first ? 14 : 30)
        .padding(.bottom, 2)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}
