//
//  QuietHoursTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@Suite("QuietHours")
struct QuietHoursTests {
    private let calendar = TestClock.calendar()
    /// 22:00 to 07:00, across midnight.
    private let night = QuietHoursWindow(fromMinutes: 22 * 60, untilMinutes: 7 * 60)

    private func at(_ time: String) -> Date {
        TestClock.date("2026-10-01 \(time)")
    }

    @Test("An overnight window is quiet from the start, through midnight, until the end (end excluded)",
          arguments: [("21:59", false), ("22:00", true), ("23:30", true), ("00:00", true), ("06:59", true),
                      ("07:00", false), ("12:00", false)])
    func overnight(time: String, quiet: Bool) {
        #expect(QuietHours.isQuiet(at: at(time), window: night, calendar: calendar) == quiet)
    }

    @Test("A daytime window works the same way")
    func daytime() {
        let siesta = QuietHoursWindow(fromMinutes: 13 * 60, untilMinutes: 15 * 60)

        #expect(QuietHours.isQuiet(at: at("13:00"), window: siesta, calendar: calendar))
        #expect(!QuietHours.isQuiet(at: at("15:00"), window: siesta, calendar: calendar))
        #expect(!QuietHours.isQuiet(at: at("12:59"), window: siesta, calendar: calendar))
    }

    @Test("No window, or an empty one, is never quiet")
    func noWindow() {
        let empty = QuietHoursWindow(fromMinutes: 600, untilMinutes: 600)

        #expect(!QuietHours.isQuiet(at: at("03:00"), window: nil, calendar: calendar))
        #expect(!QuietHours.isQuiet(at: at("10:00"), window: empty, calendar: calendar))
    }

    @Test("A client running late always comes through, and a same-day cancellation too")
    func urgentAlerts() {
        let now = at("23:00")
        let today = at("15:00")
        let tomorrow = TestClock.date("2026-10-02 10:00")

        #expect(QuietHours.shouldDeliverNow(kind: .clientRunningLate, at: now, window: night, calendar: calendar))
        #expect(QuietHours.shouldDeliverNow(kind: .cancellation, visitStartsAt: today, at: now, window: night,
                                            calendar: calendar))
        #expect(!QuietHours.shouldDeliverNow(kind: .cancellation, visitStartsAt: tomorrow, at: now, window: night,
                                             calendar: calendar))
    }

    @Test("Everything else waits at night and arrives by day", arguments: AlertKind.allCases.filter {
        $0 != .clientRunningLate && $0 != .cancellation
    })
    func nonUrgentAlerts(kind: AlertKind) {
        #expect(!QuietHours.shouldDeliverNow(kind: kind, at: at("23:00"), window: night, calendar: calendar))
        #expect(QuietHours.shouldDeliverNow(kind: kind, at: at("10:00"), window: night, calendar: calendar))
    }

    @Test("Held alerts are released when the window ends: this morning, or tomorrow morning if it is evening")
    func release() {
        #expect(QuietHours.nextRelease(after: at("23:00"), window: night, calendar: calendar)
            == TestClock.date("2026-10-02 07:00"))
        #expect(QuietHours.nextRelease(after: at("03:00"), window: night, calendar: calendar) == at("07:00"))
        #expect(QuietHours.nextRelease(after: at("12:00"), window: night, calendar: calendar) == nil)
    }

    @Test("The window follows the business time zone")
    func timeZone() {
        // 22:30 in São Paulo is 01:30 UTC the next day: quiet in São Paulo, not in a UTC calendar at 01:30? Both quiet.
        // 17:00 in Lisbon is 13:00 in São Paulo: not quiet in either.
        let lisbon = TestClock.calendar("Europe/Lisbon")
        let evening = TestClock.date("2026-10-01 22:30", zone: "Europe/Lisbon")

        #expect(QuietHours.isQuiet(at: evening, window: night, calendar: lisbon))
        #expect(!QuietHours.isQuiet(at: evening, window: night, calendar: calendar), "19:30 in São Paulo")
    }
}
