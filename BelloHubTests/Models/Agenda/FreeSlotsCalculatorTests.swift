//
//  FreeSlotsCalculatorTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@Suite("FreeSlotsCalculator")
struct FreeSlotsCalculatorTests {
    /// Thursday 2026-10-08, a working day of Maria's week, a week after `TestClock.now`.
    private let thursday = TestClock.date("2026-10-08 12:00")

    private func slots(
        _ day: Date? = nil, minutes: Int = 60, step: Int = 30, now: Date = TestClock.now,
        settings: AvailabilitySettings = makeAvailability(),
        appointments: [DateInterval] = [], blocks: [DateInterval] = []
    ) -> [Date] {
        FreeSlotsCalculator.slots(for: FreeSlotsRequest(
            day: day ?? thursday, durationMinutes: minutes, now: now, settings: settings,
            appointments: appointments, blocks: blocks, stepMinutes: step
        ))
    }

    private func clock(_ dates: [Date], zone: String = "America/Sao_Paulo") -> [String] {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: zone)
        formatter.dateFormat = "HH:mm"
        return dates.map(formatter.string(from:))
    }

    @Test("A working day offers starts around the lunch break: 09:00 to 11:30, then 13:30 to 18:00")
    func plainDay() {
        let result = clock(slots())

        #expect(result.first == "09:00")
        #expect(result.contains("11:30"))
        #expect(!result.contains("12:00"), "a visit at 12:00 would run into lunch at 12:30")
        #expect(!result.contains("12:30"))
        #expect(result.contains("13:30"))
        #expect(result.last == "18:00", "the last 60-minute start that ends by 19:00")
        #expect(result.count == 16)
    }

    @Test("A visit already booked, plus the 15-minute buffer, removes the times around it")
    func bufferAroundAVisit() {
        let booked = DateInterval(start: TestClock.date("2026-10-08 15:00"), end: TestClock.date("2026-10-08 16:30"))
        let result = clock(slots(appointments: [booked]))

        #expect(result.contains("13:30"), "ends 14:30, 30 minutes before: more than the buffer")
        #expect(!result.contains("14:00"), "ends 15:00, inside the buffer of the booked visit")
        #expect(!result.contains("16:30"), "starts at the visit's end, no buffer")
        #expect(!result.contains("16:00"))
        #expect(result.contains("17:00"), "starts 30 minutes after the visit ends")
        #expect(result.count == 10)
    }

    @Test("A block closes the time without adding a buffer around it")
    func blockHasNoBuffer() {
        let block = DateInterval(start: TestClock.date("2026-10-08 15:00"), end: TestClock.date("2026-10-08 16:00"))
        let result = clock(slots(blocks: [block]))

        #expect(result.contains("14:00"), "ends exactly when the block starts")
        #expect(result.contains("16:00"), "starts exactly when the block ends")
        #expect(!result.contains("14:30"))
    }

    @Test("A day off, a day outside the week and a past day offer nothing")
    func closedDays() {
        let dayOff = DayOff(id: UUID(), startDate: TestClock.date("2026-10-08 00:00"),
                            endDate: TestClock.date("2026-10-09 00:00"), kind: .vacation)

        #expect(slots(settings: makeAvailability(daysOff: [dayOff])).isEmpty)
        #expect(slots(TestClock.date("2026-10-12 12:00")).isEmpty, "Monday: she works Tuesday to Saturday")
        #expect(slots(TestClock.date("2026-09-24 12:00")).isEmpty, "a day in the past")
    }

    @Test("Minimum notice hides starts that are too soon")
    func minimumNotice() {
        let today = TestClock.date("2026-10-01 00:00")
        let result = clock(slots(TestClock.now, now: TestClock.now))

        // Thursday Oct 1, now is 12:00 with 2 hours of notice: nothing before 14:00.
        #expect(result.first == "14:00")
        #expect(!result.contains("13:30"))
        _ = today
    }

    @Test("The booking window ends after the configured number of days")
    func maxHorizon() {
        let far = TestClock.date("2026-12-31 12:00")

        #expect(slots(far, settings: makeAvailability(maxDaysAhead: 60)).isEmpty)
        #expect(!slots(far, settings: makeAvailability(maxDaysAhead: 120)).isEmpty)
    }

    @Test("A visit longer than the working stretch offers nothing, and several stretches in a day are all used")
    func windows() {
        #expect(slots(minutes: 11 * 60, settings: makeAvailability(breaks: [])).isEmpty)

        let split = AvailabilitySettings(
            weekly: [AvailabilityRule(weekday: 5, startMinutes: 540, endMinutes: 600),
                     AvailabilityRule(weekday: 5, startMinutes: 1_020, endMinutes: 1_080)],
            breaks: [], daysOff: [], bufferMinutes: 0, minNoticeHours: 0, maxDaysAhead: 60,
            timeZoneID: "America/Sao_Paulo"
        )
        #expect(clock(slots(minutes: 30, settings: split)) == ["09:00", "09:30", "17:00", "17:30"])
    }

    @Test("A weekday-specific break applies only that weekday")
    func weekdayBreak() {
        let coffee = BreakRule(weekday: 5, startMinutes: 16 * 60, endMinutes: 16 * 60 + 15, label: "Coffee")
        let thursdayResult = clock(slots(settings: makeAvailability(breaks: [coffee])))
        let friday = TestClock.date("2026-10-09 12:00")
        let fridayResult = clock(slots(friday, settings: makeAvailability(breaks: [coffee])))

        #expect(!thursdayResult.contains("15:30") && !thursdayResult.contains("16:00"))
        #expect(fridayResult.contains("15:30") && fridayResult.contains("16:00"))
    }

    @Test("The day is the business day: an instant that is Friday in UTC is still Thursday in São Paulo")
    func businessDay() {
        // 2026-10-09 01:00 UTC is Thursday 22:00 in São Paulo.
        let instant = Date(timeIntervalSince1970: TestClock.date("2026-10-08 22:00").timeIntervalSince1970)
        let result = clock(slots(instant))

        #expect(result.first == "09:00")
        #expect(result.count == 16)
    }

    // MARK: - Daylight saving (docs/16-MARKETS.md section 3)

    /// A window that spans the clock change, so the real length of the stretch differs from the wall-clock length.
    private func overnight(_ zone: String, weekday: Int, from start: Int = 0, to end: Int = 300)
        -> AvailabilitySettings {
        AvailabilitySettings(
            weekly: [AvailabilityRule(weekday: weekday, startMinutes: start, endMinutes: end)], breaks: [], daysOff: [],
            bufferMinutes: 0, minNoticeHours: 0, maxDaysAhead: 365, timeZoneID: zone
        )
    }

    private func count(zone: String, day: String, weekday: Int, from: Int = 0, to: Int = 300) -> Int {
        let request = FreeSlotsRequest(
            day: TestClock.date("\(day) 12:00", zone: zone), durationMinutes: 60,
            now: TestClock.date("2026-02-01 12:00", zone: zone),
            settings: overnight(zone, weekday: weekday, from: from, to: to), stepMinutes: 60
        )
        return FreeSlotsCalculator.slots(for: request).count
    }

    struct ClockChange: Sendable {
        let zone: String
        let day: String
        /// Slots in the 00:00 to 05:00 stretch: 5 hours normally, 4 when an hour is skipped, 6 when one repeats.
        let expected: Int
    }

    static let clockChanges = [
        ClockChange(zone: "Europe/Lisbon", day: "2026-03-29", expected: 4),
        ClockChange(zone: "Europe/Lisbon", day: "2026-10-25", expected: 6),
        ClockChange(zone: "Europe/Madrid", day: "2026-03-29", expected: 4),
        ClockChange(zone: "Europe/Madrid", day: "2026-10-25", expected: 6),
        ClockChange(zone: "America/New_York", day: "2026-03-08", expected: 4),
        ClockChange(zone: "America/New_York", day: "2026-11-01", expected: 6)
    ]

    @Test("Spring forward removes an hour, fall back adds one, in every zone that changes", arguments: clockChanges)
    func daylightSavingDays(change: ClockChange) {
        let slots = count(zone: change.zone, day: change.day, weekday: 1)

        #expect(slots == change.expected, "\(change.zone) \(change.day)")
    }

    @Test("A normal day in the same zones has the full five hours")
    func ordinaryDays() {
        #expect(count(zone: "Europe/Lisbon", day: "2026-03-22", weekday: 1) == 5)
        #expect(count(zone: "America/New_York", day: "2026-03-15", weekday: 1) == 5)
    }

    @Test("Mexico City (no daylight saving since 2022) and São Paulo (none since 2019) never change length")
    func zonesWithoutDaylightSaving() {
        for day in ["2026-03-29", "2026-10-25", "2026-04-05", "2026-11-01"] {
            #expect(count(zone: "America/Mexico_City", day: day, weekday: 1, to: 300) == 5, "Mexico City \(day)")
            #expect(count(zone: "America/Sao_Paulo", day: day, weekday: 1, to: 300) == 5, "São Paulo \(day)")
        }
    }

    @Test("A working day of 09:00 to 19:00 is unaffected by a change at night")
    func daytimeIsUnaffected() {
        #expect(count(zone: "Europe/Lisbon", day: "2026-03-29", weekday: 1, from: 540, to: 1_140) == 10)
        #expect(count(zone: "Europe/Lisbon", day: "2026-10-25", weekday: 1, from: 540, to: 1_140) == 10)
    }

    @Test("The same wall-clock slot is a different instant in São Paulo and Lisbon")
    func sameWallClockDifferentInstant() {
        let lisbon = clock(slots(TestClock.date("2026-10-08 12:00", zone: "Europe/Lisbon"),
                                 now: TestClock.date("2026-10-01 12:00", zone: "Europe/Lisbon"),
                                 settings: makeAvailability(timeZoneID: "Europe/Lisbon")), zone: "Europe/Lisbon")

        #expect(lisbon.first == "09:00")
    }
}
