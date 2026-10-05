import Foundation

/// A post or a notice, in the order a stream shows them.
nonisolated enum StreamItem: Identifiable, Equatable {
    case entry(Entry)
    case notice(Notice)

    var id: String {
        switch self {
        case let .entry(entry): "post-\(entry.id)"
        case let .notice(notice): "notice-\(notice.id)"
        }
    }

    /// Notices go between the posts by position: 0 before the first post,
    /// N after the Nth, and one past the end goes last. Those sharing a
    /// place keep the server's order.
    static func items(entries: [Entry], notices: [Notice]) -> [StreamItem] {
        var items: [StreamItem] = []
        items.reserveCapacity(entries.count + notices.count)
        func placed(at index: Int) -> [StreamItem] {
            notices.filter { min($0.position, entries.count) == index }.map(StreamItem.notice)
        }
        for (index, entry) in entries.enumerated() {
            items += placed(at: index)
            items.append(.entry(entry))
        }
        items += placed(at: entries.count)
        return items
    }
}
