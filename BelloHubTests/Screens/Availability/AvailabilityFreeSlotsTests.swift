//
//  AvailabilityFreeSlotsTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

/// The free times that come out of availability **as the Availability screen edits it** (exit criterion of S5): breaks,
/// the buffer, days off and daylight-saving change days, with the settings built by `AvailabilityEditor`. The
/// calculator's own table tests are in `FreeSlotsCalculatorTests`; these prove the editor's output feeds it correctly.
@Suite("Availability to free slots")
struct AvailabilityFreeSlotsTests {
    private func slots(
        _ settings: AvailabilitySettings, on day: String, zone: String = "America/Sao_Paulo", minutes: Int = 60,
        now: Date = TestClock.now, appointments: [DateInterval] = []
    ) -> [String] {
        let request = FreeSlotsRequest(
            day: TestClock.date("\(day) 12:00", zone: zone), durationMinutes: minutes, now: now, settings: settings,
            appointments: appointments, stepMinutes: 30
        )
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: zone)
        formatter.dateFormat = "HH:mm"
        return FreeSlotsCalculator.slots(for: request).map(formatter.string(from:))
    }

    private func edited(_ base: AvailabilitySettings, _ change: (AvailabilitySettings) throws -> AvailabilitySettings)
        rethrows -> AvailabilitySettings {
        try change(base)
    }

    @Test("A morning and an evening stretch with a break: only the stretches, minus the break")
    func splitDay() throws {
        let base = makeAvailability(breaks: [])
        let split = try edited(base) {
            try AvailabilityEditor.replacingStretches(
                of: 5, with: [StretchDraft(startMinutes: 540, endMinutes: 720), StretchDraft(startMinutes: 840,
                    endMinutes: 1080)],
                in: $0
            ).get()
        }
        // Thursday 2026-10-08.
        #expect(slots(split, on: "2026-10-08") == ["09:00", "09:30", "10:00", "10:30", "11:00", "14:00", "14:30",
            "15:00", "15:30", "16:00", "16:30", "17:00"])
    }

    @Test("A break added from the screen removes the starts that would run into it")
    func addedBreak() throws {
        let base = makeAvailability(breaks: [])
        let coffee = BreakRule(weekday: nil, startMinutes: 15 * 60 + 30, endMinutes: 15 * 60 + 45,
            label: "Coffee break")
        let updated = try AvailabilityEditor.savingBreak(coffee, at: nil, fallbackLabel: "Break", in: base).get()
        let with = slots(updated, on: "2026-10-08", minutes: 30)
        let without = slots(base, on: "2026-10-08", minutes: 30)
        #expect(without.contains("15:30") && !with.contains("15:30"))
        #expect(with.contains("15:00") && with.contains("16:00"))
        #expect(!slots(updated, on: "2026-10-08", minutes: 60).contains("15:00"),
            "an hour from 15:00 runs into the coffee break")
    }

    @Test("A change of buffer from the menu changes the times around a booked visit")
    func bufferChange() {
        var base = makeAvailability(breaks: [])
        let booked = DateInterval(start: TestClock.date("2026-10-08 15:00"), end: TestClock.date("2026-10-08 16:00"))
        base.bufferMinutes = 0
        let none = slots(base, on: "2026-10-08", appointments: [booked])
        base.bufferMinutes = 30
        let half = slots(base, on: "2026-10-08", appointments: [booked])
        #expect(none.contains("14:00") && none.contains("16:00"))
        #expect(!half.contains("14:00") && !half.contains("16:00") && half.contains("13:30") && half.contains("16:30"))
    }

    @Test("A vacation saved from the sheet closes every day in it and only those")
    func vacation() throws {
        let vacation = DayOff(
            id: UUID(), startDate: TestClock.date("2026-10-13 15:00"), endDate: TestClock.date("2026-10-15 08:00"),
            kind: .vacation
        )
        let updated = try AvailabilityEditor.savingDayOff(vacation, now: TestClock.now, in: makeAvailability()).get()
        #expect(slots(updated, on: "2026-10-13").isEmpty && slots(updated, on: "2026-10-14").isEmpty)
        #expect(slots(updated, on: "2026-10-15").isEmpty)
        #expect(!slots(updated, on: "2026-10-16").isEmpty, "the day after the last day is open")
        #expect(!slots(updated, on: "2026-10-09").isEmpty, "the day before the first is open")
    }

    @Test("Switching a weekday off from the screen closes it; switching it on opens 09:00 to 18:00")
    func weekdayToggle() {
        let closedThursday = AvailabilityEditor.setting(5, open: false, in: makeAvailability())
        #expect(slots(closedThursday, on: "2026-10-08").isEmpty)
        let openMonday = AvailabilityEditor.setting(2, open: true, in: makeAvailability())
        let monday = slots(openMonday, on: "2026-10-12")
        #expect(monday.first == "09:00" && monday.last == "17:00")
    }

    @Test("The days off a calendar year apart do not interfere", arguments: ["2026-12-24", "2027-01-02"])
    func yearBoundary(day: String) throws {
        let vacation = DayOff(
            id: UUID(), startDate: TestClock.date("2026-12-22 00:00"), endDate: TestClock.date("2027-01-05 00:00"),
            kind: .vacation
        )
        let wide = makeAvailability(maxDaysAhead: 365)
        let updated = try AvailabilityEditor.savingDayOff(vacation, now: TestClock.now, in: wide).get()
        #expect(slots(updated, on: day).isEmpty)
        #expect(!slots(updated, on: "2027-01-06").isEmpty)
    }

    // MARK: - Daylight saving change days, with the stretches the screen can make

    /// A split working day (morning and afternoon) on the day the clocks change, in each zone that changes. The
    /// wall-clock stretches are honored: a 09:00 to 12:00 stretch has three bookable hours whatever happened at 2
    /// a.m.
    @Test("A split day on a daylight-saving change day keeps its wall-clock stretches", arguments: [
        ("Europe/Lisbon", "2026-03-29"), ("Europe/Lisbon", "2026-10-25"),
        ("Europe/Madrid", "2026-03-29"), ("Europe/Madrid", "2026-10-25"),
        ("America/New_York", "2026-03-08"), ("America/New_York", "2026-11-01")
    ])
    func splitDayOnChangeDay(zone: String, day: String) throws {
        let calendar = TestClock.calendar(zone)
        let weekday = calendar.component(.weekday, from: TestClock.date("\(day) 12:00", zone: zone))
        var base = makeAvailability(timeZoneID: zone, weekdays: [], breaks: [], bufferMinutes: 0, minNoticeHours: 0)
        base = try AvailabilityEditor.replacingStretches(
            of: weekday, with: [StretchDraft(startMinutes: 540, endMinutes: 720), StretchDraft(startMinutes: 840,
                endMinutes: 1080)],
            in: base
        ).get()
        let early = TestClock.date("\(day) 12:00", zone: zone).addingTimeInterval(-7 * 86_400)
        let result = slots(base, on: day, zone: zone, now: early)
        #expect(result == ["09:00", "09:30", "10:00", "10:30", "11:00", "14:00", "14:30", "15:00", "15:30", "16:00",
            "16:30", "17:00"], "\(zone) \(day)")
    }

    @Test("A break across the change hour is not shifted: lunch at 12:30 stays at 12:30 on a change day")
    func breakOnChangeDay() throws {
        let zone = "Europe/Madrid"
        let base = makeAvailability(timeZoneID: zone, weekdays: [1], startMinutes: 540, endMinutes: 1080,
            bufferMinutes: 0, minNoticeHours: 0)
        let week = TestClock.date("2026-03-29 12:00", zone: zone).addingTimeInterval(-7 * 86_400)
        let result = slots(base, on: "2026-03-29", zone: zone, now: week)
        #expect(!result.contains("12:30") && !result.contains("13:00") && result.contains("13:30")
            && result.contains("12:00") == false)
    }
}
