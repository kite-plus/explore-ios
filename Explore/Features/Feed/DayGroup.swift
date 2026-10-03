import Foundation

/// Posts under the day they came out on, as the website's streams group
/// them: neighbouring posts of one calendar day share a heading, and posts
/// without a date share one of their own.
nonisolated struct DayGroup: Identifiable, Equatable {
    /// The start of the day, or nil for posts without a date.
    let day: Date?
    let entries: [Entry]

    /// A day can only come back after an undated run, so the first post
    /// names the group.
    var id: String { entries.first?.id ?? "empty" }

    static func groups(of entries: [Entry], calendar: Calendar = .current) -> [DayGroup] {
        var days: [Date?] = []
        var runs: [[Entry]] = []
        for entry in entries {
            let day = entry.publishedAt.map { calendar.startOfDay(for: $0) }
            if let last = days.last, last == day {
                runs[runs.count - 1].append(entry)
            } else {
                days.append(day)
                runs.append([entry])
            }
        }
        return zip(days, runs).map { DayGroup(day: $0, entries: $1) }
    }

    /// "Today" or "Yesterday" with the date beside it, or the date alone,
    /// with the year only when it is not this one.
    func heading(now: Date = .now, calendar: Calendar = .current) -> (name: String, date: String?) {
        guard let day else { return (String(localized: "Date unknown"), nil) }
        var style = Date.FormatStyle.dateTime.month(.wide).day().weekday(.abbreviated)
        if calendar.component(.year, from: day) != calendar.component(.year, from: now) {
            style = style.year()
        }
        let date = day.formatted(style)
        if calendar.isDate(day, inSameDayAs: now) {
            return (String(localized: "Today"), date)
        }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now), calendar.isDate(day, inSameDayAs: yesterday) {
            return (String(localized: "Yesterday"), date)
        }
        return (date, nil)
    }

    /// A post under a heading that names an earlier day gives its time of
    /// day; today's and undated posts say how long ago.
    func showsClockTime(now: Date = .now, calendar: Calendar = .current) -> Bool {
        guard let day else { return false }
        return !calendar.isDate(day, inSameDayAs: now)
    }
}
