//
//  WeekSummaryTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@Suite("WeekSummary")
struct WeekSummaryTests {
    private let days = CalendarDays(timeZone: TestClock.saoPaulo, firstWeekday: 2)

    private func summary(
        now: String = "2026-10-01 12:00", appointments: [Appointment] = [], blocks: [TimeBlock] = [],
        settings: AvailabilitySettings = makeAvailability(breaks: [], bufferMinutes: 0), shortest: Int = 60
    ) -> WeekSummary {
        WeekSummary.make(
            WeekSummary.Input(
                now: TestClock.date(now), settings: settings, appointments: appointments, blocks: blocks,
                shortestServiceMinutes: shortest
            ),
            days: days
        )
    }

    @Test("The week shows her working days, Tuesday to Saturday, from the week's first day")
    func rows() {
        let result = summary()
        #expect(result.weekStart == TestClock.date("2026-09-28 00:00"))
        let weekdays = result.rows.map { TestClock.calendar().component(.weekday, from: $0.day) }
        #expect(weekdays == [3, 4, 5, 6, 7])
        #expect(result.rows.filter(\.isToday).map { TestClock.calendar().component(.weekday, from: $0.day) } == [5])
    }

    @Test("Each day counts its booked visits and the visits that still fit")
    func capacity() {
        // Friday 09:00 to 19:00 is ten one-hour slots; one visit leaves nine.
        let visit = makeVisit(start: friday("10:00"))
        let result = summary(appointments: [visit])
        let row = result.rows.first { TestClock.calendar().component(.weekday, from: $0.day) == 6 }
        #expect(row?.booked == 1)
        #expect(row?.capacity == 10)
        #expect(row?.fraction == 0.1)
    }

    @Test("Days that have passed show what happened and no open room")
    func pastDays() {
        let tuesday = makeVisit(start: TestClock.date("2026-09-29 10:00"), status: .completed)
        let result = summary(appointments: [tuesday])
        let row = result.rows.first { TestClock.calendar().component(.weekday, from: $0.day) == 3 }
        #expect(row?.booked == 1 && row?.capacity == 1 && row?.fraction == 1)
    }

    @Test("A block takes the room away from the day and from the open count")
    func blocked() {
        let open = summary().openSlotCount
        let block = makeBlock(start: friday("09:00"), minutes: 600)
        #expect(summary(blocks: [block]).openSlotCount == open - 10)
    }

    @Test("Visits left today are the ones not over yet")
    func leftToday() {
        let over = makeVisit(start: TestClock.date("2026-10-01 09:00"))
        let running = makeVisit(start: TestClock.date("2026-10-01 11:30"))
        let later = makeVisit(start: TestClock.date("2026-10-01 15:00"))
        let cancelled = makeVisit(start: TestClock.date("2026-10-01 16:00"), status: .cancelled)
        let tomorrow = makeVisit(start: friday("10:00"))
        let result = summary(appointments: [over, running, later, cancelled, tomorrow])
        #expect(result.leftToday == 2)
    }

    @Test("The suggestions are the first visits that fit from now, one after another, at most five")
    func suggestions() {
        let result = summary()
        #expect(result.suggestions.count == WeekSummary.maximumSuggestions)
        #expect(result.suggestions.map(\.start) == result.suggestions.map(\.start).sorted())
        // Thursday 12:00 now, one-hour visits and no buffer: 12:00, 13:00, 14:00 ...
        #expect(result.suggestions.map(\.start) == (12...16).map { TestClock.date("2026-10-01 \($0):00") })
    }

    @Test("A day with visits but no working hours still shows its bookings")
    func visitsOnAClosedDay() {
        let sunday = makeVisit(start: TestClock.date("2026-10-04 10:00"))
        let result = summary(appointments: [sunday])
        let row = result.rows.first { TestClock.calendar().component(.weekday, from: $0.day) == 1 }
        #expect(row?.booked == 1)
    }

    @Test("The shortest service sets what an open slot is")
    func shortestService() {
        let short = summary(shortest: 30).openSlotCount
        let long = summary(shortest: 120).openSlotCount
        #expect(short > long)
    }
}
