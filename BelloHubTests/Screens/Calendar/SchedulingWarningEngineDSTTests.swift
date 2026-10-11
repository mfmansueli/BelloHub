//
//  SchedulingWarningEngineDSTTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

/// The engine on the days the clocks change (and on the zones that stopped changing them): the working stretch, the
/// break and an overlap are read in real time, so a wall-clock rule never shifts by an hour.
@Suite("SchedulingWarningEngine on daylight-saving days")
struct SchedulingWarningEngineDSTTests {
    @Test("A visit that ends exactly at closing time fits; half an hour later does not", arguments: ZoneDay.all)
    func closingOnChangeDay(day: ZoneDay) {
        let lastHour = day.midnight.addingTimeInterval(TimeInterval((day.windowHours - 1) * 3_600))
        let fits = SchedulingWarningInput(
            interval: DateInterval(start: lastHour, duration: 3_600), settings: day.overnightSettings,
            appointments: [], blocks: [], now: day.midnight.addingTimeInterval(-86_400 * 3)
        )
        #expect(SchedulingWarningEngine.warnings(for: fits).isEmpty)
        var spills = fits
        spills.interval = DateInterval(start: lastHour.addingTimeInterval(1_800), duration: 3_600)
        #expect(SchedulingWarningEngine.warnings(for: spills) == [.outsideHours(.afterClosing)])
        var opening = fits
        opening.interval = DateInterval(start: day.midnight.addingTimeInterval(-1_800), duration: 3_600)
        #expect(SchedulingWarningEngine.warnings(for: opening).contains(.outsideHours(.beforeOpening))
            || SchedulingWarningEngine.warnings(for: opening).contains(.closedDay))
    }

    @Test("Two visits that overlap by real time across a clock change are an overlap", arguments: ZoneDay.all)
    func overlapAcrossChange(day: ZoneDay) {
        let first = makeVisit(start: day.midnight.addingTimeInterval(3_600), minutes: 120)
        let query = SchedulingWarningInput(
            interval: DateInterval(start: day.midnight.addingTimeInterval(2 * 3_600 + 1_800), duration: 3_600),
            settings: day.overnightSettings, appointments: [first], blocks: [],
            now: day.midnight.addingTimeInterval(-86_400 * 3)
        )
        #expect(SchedulingWarningEngine.warnings(for: query) == [.overlap(with: first.id)])
    }

    @Test("A break written in wall-clock time is the same real stretch it is on any other day", arguments: ZoneDay.all)
    func breakOnChangeDay(day: ZoneDay) {
        var settings = day.overnightSettings
        // 04:00 to 05:00 local exists on every one of these days, whatever the clocks did before it.
        settings.breaks = [BreakRule(weekday: nil, startMinutes: 240, endMinutes: 300, label: "Early")]
        let calendar = day.calendar
        let start = calendar.date(bySettingHour: 4, minute: 15, second: 0, of: day.midnight) ?? day.midnight
        let query = SchedulingWarningInput(
            interval: DateInterval(start: start, duration: 1_800), settings: settings, appointments: [], blocks: [],
            now: day.midnight.addingTimeInterval(-86_400 * 3)
        )
        #expect(SchedulingWarningEngine.warnings(for: query) == [.insideBreak(label: "Early")])
    }
}
