import Foundation
import Testing
@testable import Explore

struct DayGroupTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        return calendar
    }

    /// 2026-10-04 15:00 in Shanghai.
    private let now = Date(timeIntervalSince1970: 1_791_097_200)

    private func entry(_ id: String, hoursAgo: Double?) -> Entry {
        Entry(
            id: id, title: id, url: "https://blog.example.com/\(id)", excerpt: nil, imagePath: nil,
            publishedAt: hoursAgo.map { now.addingTimeInterval(-$0 * 3600) }, tags: [],
            linkStatus: .unknown, linkCheckedAt: nil, blog: nil
        )
    }

    @Test func groupsNeighbouringPostsOfOneDay() {
        let entries = [
            entry("a", hoursAgo: 1), entry("b", hoursAgo: 14),
            entry("c", hoursAgo: 16), entry("d", hoursAgo: 40), entry("e", hoursAgo: nil),
        ]
        let groups = DayGroup.groups(of: entries, calendar: calendar)
        #expect(groups.map { $0.entries.map(\.id) } == [["a", "b"], ["c"], ["d"], ["e"]])
        #expect(groups.last?.day == nil)
        #expect(Set(groups.map(\.id)).count == groups.count)
    }

    @Test func namesTodayAndYesterdayWithTheDate() {
        let groups = DayGroup.groups(of: [entry("a", hoursAgo: 1), entry("b", hoursAgo: 20), entry("c", hoursAgo: 50)], calendar: calendar)
        let today = groups[0].heading(now: now, calendar: calendar)
        let yesterday = groups[1].heading(now: now, calendar: calendar)
        let earlier = groups[2].heading(now: now, calendar: calendar)
        // In the simulator's language, which need not be English.
        #expect(today.name == String(localized: "Today") && today.date != nil)
        #expect(yesterday.name == String(localized: "Yesterday") && yesterday.date != nil)
        #expect(earlier.date == nil && earlier.name != today.name && earlier.name != yesterday.name)
    }

    @Test func givesTheClockTimeOnlyForEarlierDays() {
        let groups = DayGroup.groups(of: [entry("a", hoursAgo: 1), entry("b", hoursAgo: 20), entry("c", hoursAgo: nil)], calendar: calendar)
        #expect(groups.map { $0.showsClockTime(now: now, calendar: calendar) } == [false, true, false])
    }
}
