//
//  CalendarDayLayoutTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@Suite("CalendarDayLayout")
struct CalendarDayLayoutTests {
    private let days = CalendarDays(timeZone: TestClock.saoPaulo)
    private let settings = makeAvailability()

    private func scale(_ visible: CalendarDayLayout.VisibleMinutes? = nil) -> CalendarDayLayout.Scale {
        CalendarDayLayout.Scale(
            settings: settings, visible: visible ?? CalendarDayLayout.VisibleMinutes(start: 8 * 60, end: 20 * 60),
            days: days
        )
    }

    private func layout(
        appointments: [Appointment] = [], blocks: [TimeBlock] = [], day: String = "2026-10-02"
    ) -> CalendarDayLayout {
        CalendarDayLayout.make(
            day: TestClock.date("\(day) 00:00"), appointments: appointments, blocks: blocks, scale: scale()
        )
    }

    // MARK: - Columns

    private func stretch(_ start: String, _ end: String) -> CalendarDayLayout.Stretch {
        CalendarDayLayout.Stretch(
            id: UUID(), interval: DateInterval(start: friday(start), end: friday(end))
        )
    }

    @Test("Visits that do not overlap each take the whole width")
    func separate() {
        let placed = CalendarDayLayout.columns(for: [stretch("09:00", "10:00"), stretch("10:00", "11:00")])
        #expect(placed.map(\.column) == [0, 0])
        #expect(placed.map(\.columnCount) == [1, 1])
    }

    @Test("Two visits that overlap share the width in two columns")
    func pair() {
        let first = stretch("09:00", "10:30")
        let second = stretch("10:00", "11:00")
        let placed = CalendarDayLayout.columns(for: [second, first])
        #expect(placed.first { $0.id == first.id }?.column == 0)
        #expect(placed.first { $0.id == second.id }?.column == 1)
        #expect(placed.allSatisfy { $0.columnCount == 2 })
    }

    @Test("A chain of overlaps is one cluster, and a later visit starts a new one")
    func chain() {
        let first = stretch("09:00", "10:00")
        let second = stretch("09:30", "11:00")
        let third = stretch("10:30", "11:30")
        let later = stretch("14:00", "15:00")
        let placed = CalendarDayLayout.columns(for: [first, second, third, later])
        #expect(placed.first { $0.id == first.id }?.column == 0)
        #expect(placed.first { $0.id == second.id }?.column == 1)
        // The third reuses the first column, which is free again at 10:30.
        #expect(placed.first { $0.id == third.id }?.column == 0)
        #expect(placed.filter { $0.id != later.id }.allSatisfy { $0.columnCount == 2 })
        #expect(placed.first { $0.id == later.id }?.columnCount == 1)
    }

    @Test("Three at once need three columns")
    func triple() {
        let placed = CalendarDayLayout.columns(for: [
            stretch("09:00", "10:00"), stretch("09:15", "10:00"), stretch("09:30", "10:00")
        ])
        #expect(Set(placed.map(\.column)) == [0, 1, 2])
        #expect(placed.allSatisfy { $0.columnCount == 3 })
    }

    @Test("No stretches, no visits")
    func none() {
        #expect(CalendarDayLayout.columns(for: []).isEmpty)
    }

    // MARK: - The day

    @Test("The layout holds the visit, the lunch break and a block, and hides a cancelled visit")
    func day() {
        let kept = makeVisit(start: friday("10:00"))
        let cancelled = makeVisit(start: friday("15:00"), status: .cancelled)
        let block = makeBlock(start: friday("16:00"), minutes: 60, reason: "Family")
        let result = layout(appointments: [kept, cancelled], blocks: [block])
        #expect(result.visits.map(\.id) == [kept.id])
        #expect(result.bands.count == 2)
        #expect(result.bands.contains { $0.kind == .breakTime(label: "Lunch") })
        #expect(result.bands.contains { $0.kind == .blocked(id: block.id) })
        #expect(!result.isClosed)
        #expect(result.workingWindows.count == 1)
    }

    @Test("A no-show stays in the calendar, marked")
    func noShow() {
        let missed = makeVisit(start: friday("10:00"), status: .noShow)
        #expect(layout(appointments: [missed]).visits.map(\.id) == [missed.id])
    }

    @Test("A weekday she does not work, and a day off, are closed")
    func closed() {
        #expect(layout(day: "2026-10-04").isClosed) // a Sunday
        var withOff = settings
        withOff.daysOff = [DayOff(
            id: UUID(), startDate: TestClock.date("2026-10-02 00:00"), endDate: TestClock.date("2026-10-02 00:00"),
            kind: .vacation
        )]
        let result = CalendarDayLayout.make(
            day: TestClock.date("2026-10-02 00:00"), appointments: [], blocks: [],
            scale: CalendarDayLayout.Scale(
                settings: withOff, visible: CalendarDayLayout.VisibleMinutes(start: 480, end: 1_200), days: days
            )
        )
        #expect(result.isClosed && result.dayOff?.kind == .vacation)
    }

    @Test("A position is a fraction of the column, clamped")
    func fractions() {
        let result = layout()
        #expect(result.fraction(of: friday("08:00")) == 0)
        #expect(result.fraction(of: friday("14:00")) == 0.5)
        #expect(result.fraction(of: friday("23:00")) == 1)
        #expect(result.fraction(of: friday("05:00")) == 0)
    }

    @Test("A tap lands on a half hour she can book")
    func tapTimes() {
        let result = layout()
        // 12 hours tall: 0.0 is 08:00, 0.25 is 11:00, a tap at 0.27 (11:10) snaps down to 11:00.
        #expect(result.time(atFraction: 0) == friday("08:00"))
        #expect(result.time(atFraction: 0.27) == friday("11:00"))
        #expect(result.time(atFraction: 0.3) == friday("11:30"))
        #expect(result.time(atFraction: 1) == friday("19:30"))
        #expect(result.time(atFraction: -4) == friday("08:00"))
    }

    // MARK: - Visible hours

    @Test("The visible hours span her week and widen for a visit outside it")
    func visibleMinutes() {
        let base = CalendarDayLayout.visibleMinutes(settings: settings, appointments: [], days: days)
        #expect(base == CalendarDayLayout.VisibleMinutes(start: 9 * 60, end: 19 * 60))
        let early = makeVisit(start: friday("07:20"), minutes: 40)
        let late = makeVisit(start: friday("19:30"), minutes: 60)
        let widened = CalendarDayLayout.visibleMinutes(settings: settings, appointments: [early, late], days: days)
        #expect(widened == CalendarDayLayout.VisibleMinutes(start: 7 * 60, end: 21 * 60))
    }

    @Test("A cancelled visit does not widen the hours; a block does")
    func visibleIgnoresCancelled() {
        let cancelled = makeVisit(start: friday("06:00"), status: .cancelled)
        let block = makeBlock(start: friday("20:00"), minutes: 60)
        let result = CalendarDayLayout.visibleMinutes(
            settings: settings, appointments: [cancelled], blocks: [block], days: days
        )
        #expect(result == CalendarDayLayout.VisibleMinutes(start: 9 * 60, end: 21 * 60))
    }

    @Test("The hours are never fewer than four, and a late visit that crosses midnight closes the day at midnight")
    func visibleLimits() {
        var short = settings
        short.weekly = [AvailabilityRule(weekday: 6, startMinutes: 600, endMinutes: 660)]
        let tiny = CalendarDayLayout.visibleMinutes(settings: short, appointments: [], days: days)
        #expect(tiny.end - tiny.start == 4 * 60)
        let overnight = makeVisit(start: TestClock.date("2026-10-02 23:00"), minutes: 120)
        let result = CalendarDayLayout.visibleMinutes(settings: settings, appointments: [overnight], days: days)
        #expect(result.end == 24 * 60)
    }

    @Test("With no hours set, the default window is shown")
    func visibleDefault() {
        var empty = settings
        empty.weekly = []
        let result = CalendarDayLayout.visibleMinutes(settings: empty, appointments: [], days: days)
        #expect(result == CalendarDayLayout.defaultVisible)
    }

    // MARK: - Daylight saving

    @Test("The column of a change day has one hour mark per real hour and places a visit by elapsed time",
          arguments: ZoneDay.all)
    func changeDay(day: ZoneDay) {
        let calendarDays = CalendarDays(timeZone: TimeZone(identifier: day.zone) ?? .gmt)
        let scale = CalendarDayLayout.Scale(
            settings: day.overnightSettings, visible: CalendarDayLayout.VisibleMinutes(start: 0, end: 360),
            days: calendarDays
        )
        let hourBeforeEnd = day.midnight.addingTimeInterval(TimeInterval((day.windowHours - 1) * 3_600))
        let visit = makeVisit(start: hourBeforeEnd)
        let layout = CalendarDayLayout.make(
            day: day.midnight, appointments: [visit], blocks: [], scale: scale
        )
        #expect(layout.hourMarks.count == day.windowHours)
        #expect(layout.window.duration == TimeInterval(day.windowHours * 3_600))
        let expected = Double(day.windowHours - 1) / Double(day.windowHours)
        #expect(abs(layout.fraction(of: hourBeforeEnd) - expected) < 0.0001)
        #expect(layout.visits.first?.id == visit.id)
        #expect(layout.workingWindows == [layout.window])
    }
}
