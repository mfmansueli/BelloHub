//
//  CalendarDays.swift
//  BelloHub
//

import Foundation

/// Days, weeks and hour marks of the calendar, always read in the **business** time zone (never the phone's), so a
/// day is the same day for her and for the booking page, and daylight-saving change days are 23 or 25 hours long.
struct CalendarDays: Sendable {
    let calendar: Calendar

    init(timeZone: TimeZone, firstWeekday: Int = 2) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        calendar.firstWeekday = firstWeekday
        self.calendar = calendar
    }

    /// The first instant of the day that contains `date`.
    func start(of date: Date) -> Date {
        calendar.startOfDay(for: date)
    }

    /// The whole day as a real interval: 23, 24 or 25 hours.
    func interval(of date: Date) -> DateInterval {
        let start = start(of: date)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(86_400)
        return DateInterval(start: start, end: end)
    }

    /// The start of the day `days` away from the day of `date`.
    func adding(days: Int, to date: Date) -> Date {
        calendar.date(byAdding: .day, value: days, to: start(of: date)) ?? date
    }

    func isSameDay(_ first: Date, _ second: Date) -> Bool {
        calendar.isDate(first, inSameDayAs: second)
    }

    /// The seven days of the week that contains `date`, starting on the week's first weekday.
    func week(containing date: Date) -> [Date] {
        let day = start(of: date)
        let weekday = calendar.component(.weekday, from: day)
        let offset = (weekday - calendar.firstWeekday + 7) % 7
        let first = adding(days: -offset, to: day)
        return (0..<7).map { adding(days: $0, to: first) }
    }

    /// The whole week as one real interval (for a query).
    func weekInterval(containing date: Date) -> DateInterval {
        let days = week(containing: date)
        guard let first = days.first, let last = days.last else { return interval(of: date) }
        return DateInterval(start: first, end: interval(of: last).end)
    }

    /// The weekday number (1 is Sunday) of the day.
    func weekday(of date: Date) -> Int {
        calendar.component(.weekday, from: date)
    }

    /// The instant of a wall-clock time on the day of `day`. A time that does not exist (spring forward) moves to
    /// the next valid one, as in `FreeSlotsCalculator`.
    func date(on day: Date, minutes: Int) -> Date {
        let dayStart = start(of: day)
        let nextDayStart = interval(of: day).end
        return FreeSlotsCalculator.instant(minutes: minutes, dayStart: dayStart, nextDayStart: nextDayStart,
                                           calendar: calendar) ?? dayStart
    }

    /// The whole hours inside `window`, as real instants: one per elapsed hour, so a 23-hour day has 23 marks and a
    /// 25-hour day has 25 (the repeated hour appears twice, which is what the clock does).
    func hourMarks(in window: DateInterval) -> [Date] {
        var marks: [Date] = []
        var mark = window.start
        while mark < window.end {
            marks.append(mark)
            mark = mark.addingTimeInterval(3_600)
        }
        return marks
    }
}
