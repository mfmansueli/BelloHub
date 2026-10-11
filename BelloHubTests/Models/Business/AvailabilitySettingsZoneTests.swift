//
//  AvailabilitySettingsZoneTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@Suite("AvailabilitySettings+Zone")
struct AvailabilitySettingsZoneTests {
    @Test("Read in another zone, her hours keep every wall-clock time and every day off keeps its date")
    func keepsHours() {
        let dayOff = DayOff(
            id: UUID(), startDate: TestClock.date("2026-10-10 00:00"), endDate: TestClock.date("2026-10-11 00:00"),
            kind: .vacation
        )
        let stored = makeAvailability(timeZoneID: "America/Sao_Paulo", daysOff: [dayOff])
        for zone in ["Europe/Rome", "Asia/Tokyo", "Pacific/Honolulu"] {
            let read = stored.inTimeZone(TimeZone(identifier: zone) ?? .gmt)
            #expect(read.timeZoneID == zone)
            #expect(read.weekly == stored.weekly && read.breaks == stored.breaks)
            #expect(read.bufferMinutes == stored.bufferMinutes && read.minNoticeHours == stored.minNoticeHours)
            #expect(read.daysOff.map(\.startDate) == [TestClock.date("2026-10-10 00:00", zone: zone)])
            #expect(read.daysOff.map(\.endDate) == [TestClock.date("2026-10-11 00:00", zone: zone)])
            #expect(read.daysOff.map(\.id) == [dayOff.id] && read.daysOff.map(\.kind) == [.vacation])
        }
        #expect(stored.inTimeZone(TestClock.saoPaulo) == stored)
    }

    @Test("A day off is closed on its own date in the business zone", arguments: ZoneMismatch.all)
    func dayOff(_ zones: ZoneMismatch) {
        var stored = zones.availability
        let start = TestClock.date("\(zones.date) 00:00", zone: zones.stored)
        stored.daysOff = [DayOff(id: UUID(), startDate: start, endDate: start, kind: .dayOff)]
        let read = stored.inTimeZone(zones.days.calendar.timeZone)
        #expect(FreeSlotsCalculator.workingWindows(on: zones.day, settings: read).isEmpty)
        #expect(!FreeSlotsCalculator.workingWindows(on: zones.days.adding(days: 1, to: zones.day), settings: read)
            .isEmpty)
        #expect(!FreeSlotsCalculator.workingWindows(on: zones.days.adding(days: -1, to: zones.day), settings: read)
            .isEmpty)
    }

    @Test("Free times of a day chosen in the business zone are that day's", arguments: ZoneMismatch.all)
    func freeTimes(_ zones: ZoneMismatch) {
        let settings = zones.availability.inTimeZone(zones.days.calendar.timeZone)
        let times = FreeSlotsCalculator.slots(for: FreeSlotsRequest(
            day: zones.day, durationMinutes: 60, now: TestClock.now, settings: settings, stepMinutes: 60
        ))
        #expect(times.first == zones.at("09:00"))
        #expect(times.last == zones.at("17:00"))
        #expect(times.allSatisfy { zones.days.isSameDay($0, zones.day) })
    }
}
