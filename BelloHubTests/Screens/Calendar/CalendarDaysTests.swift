//
//  CalendarDaysTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@Suite("CalendarDays")
struct CalendarDaysTests {
    @Test("A day is 23, 24 or 25 hours long, by what the clocks do in that zone", arguments: ZoneDay.all)
    func dayLength(day: ZoneDay) {
        let days = CalendarDays(timeZone: TimeZone(identifier: day.zone) ?? .gmt)
        let interval = days.interval(of: day.midnight.addingTimeInterval(12 * 3_600))
        #expect(interval.start == day.midnight)
        #expect(interval.duration == TimeInterval(day.dayHours * 3_600))
    }

    @Test("Adding days lands on local midnight, not on 24 hours later", arguments: ZoneDay.all)
    func addingDays(day: ZoneDay) {
        let days = CalendarDays(timeZone: TimeZone(identifier: day.zone) ?? .gmt)
        let next = days.adding(days: 1, to: day.midnight)
        #expect(next.timeIntervalSince(day.midnight) == TimeInterval(day.dayHours * 3_600))
        #expect(days.start(of: next) == next)
        #expect(days.adding(days: -1, to: next) == day.midnight)
    }

    @Test("The hour marks of a window are one per real hour", arguments: ZoneDay.all)
    func hourMarks(day: ZoneDay) {
        let days = CalendarDays(timeZone: TimeZone(identifier: day.zone) ?? .gmt)
        let window = DateInterval(start: day.midnight, end: days.date(on: day.midnight, minutes: 360))
        #expect(days.hourMarks(in: window).count == day.windowHours)
    }

    @Test("A wall-clock time that does not exist moves to the next valid one")
    func nonexistentTime() {
        let days = CalendarDays(timeZone: TimeZone(identifier: "America/New_York") ?? .gmt)
        let midnight = TestClock.date("2026-03-08 00:00", zone: "America/New_York")
        let resolved = days.date(on: midnight, minutes: 2 * 60 + 30)
        #expect(resolved == TestClock.date("2026-03-08 03:00", zone: "America/New_York"))
    }

    @Test("A week starts on the chosen weekday and has seven days")
    func week() {
        let zone = TimeZone(identifier: "America/Sao_Paulo") ?? .gmt
        let thursday = TestClock.now
        let monday = CalendarDays(timeZone: zone, firstWeekday: 2).week(containing: thursday)
        #expect(monday.count == 7)
        #expect(monday.first == TestClock.date("2026-09-28 00:00"))
        #expect(monday.last == TestClock.date("2026-10-04 00:00"))
        let sunday = CalendarDays(timeZone: zone, firstWeekday: 1).week(containing: thursday)
        #expect(sunday.first == TestClock.date("2026-09-27 00:00"))
        // A Sunday belongs to the week that started the Monday before.
        let sundayNoon = TestClock.date("2026-10-04 15:00")
        let onSunday = CalendarDays(timeZone: zone, firstWeekday: 2).week(containing: sundayNoon)
        #expect(onSunday.first == TestClock.date("2026-09-28 00:00"))
    }

    @Test("The week that holds a daylight-saving change is still seven calendar days", arguments: ZoneDay.all)
    func weekAcrossChange(day: ZoneDay) {
        let days = CalendarDays(timeZone: TimeZone(identifier: day.zone) ?? .gmt, firstWeekday: 2)
        let week = days.week(containing: day.midnight)
        #expect(week.count == 7 && week.contains(day.midnight))
        let interval = days.weekInterval(containing: day.midnight)
        #expect(interval.duration == TimeInterval((7 * 24 + day.dayHours - 24) * 3_600))
        for (first, second) in zip(week, week.dropFirst()) {
            #expect(days.start(of: first) == first && first < second)
        }
    }

    @Test("A day is the day in the business zone, not the phone's")
    func businessZone() {
        // 23:30 on Oct 1 in São Paulo is already Oct 2 in Lisbon.
        let instant = TestClock.date("2026-10-01 23:30")
        let saoPaulo = CalendarDays(timeZone: TimeZone(identifier: "America/Sao_Paulo") ?? .gmt)
        let lisbon = CalendarDays(timeZone: TimeZone(identifier: "Europe/Lisbon") ?? .gmt)
        #expect(saoPaulo.start(of: instant) == TestClock.date("2026-10-01 00:00"))
        #expect(lisbon.start(of: instant) == TestClock.date("2026-10-02 00:00", zone: "Europe/Lisbon"))
    }
}
