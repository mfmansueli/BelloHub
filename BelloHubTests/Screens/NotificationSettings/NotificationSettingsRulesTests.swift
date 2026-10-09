//
//  NotificationSettingsRulesTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@Suite("NotificationSettingsRules")
struct NotificationSettingsRulesTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Sao_Paulo") ?? .current
        return calendar
    }

    @Test("Quiet hours default to 22:00 to 07:00 and an empty window counts as off")
    func quietHours() {
        let on = NotificationSettingsRules.togglingQuietHours(.standard, on: true)
        #expect(on.quietHours == QuietHoursWindow(fromMinutes: 22 * 60, untilMinutes: 7 * 60))
        let off = NotificationSettingsRules.togglingQuietHours(on, on: false)
        #expect(off.quietHours == nil)
        var custom = NotificationPrefs.standard
        custom.quietHours = QuietHoursWindow(fromMinutes: 21 * 60, untilMinutes: 8 * 60)
        #expect(NotificationSettingsRules.togglingQuietHours(custom, on: true).quietHours?.fromMinutes == 21 * 60)
        #expect(NotificationSettingsRules.normalized(QuietHoursWindow(fromMinutes: 600, untilMinutes: 600)) == nil)
        #expect(NotificationSettingsRules.normalized(nil) == nil)
    }

    @Test("Minutes since midnight round-trip through a picker date")
    func minutes() {
        let date = NotificationSettingsRules.date(forMinutes: 18 * 60 + 30, calendar: calendar)
        #expect(NotificationSettingsRules.minutes(of: date, calendar: calendar) == 18 * 60 + 30)
        #expect(NotificationSettingsRules.minutes(of: NotificationSettingsRules.date(forMinutes: 0, calendar: calendar),
                                                  calendar: calendar) == 0)
    }

    @Test("The permission notice follows the system status")
    func permission() {
        #expect(NotificationSettingsRules.notice(for: .notDetermined) == .ask)
        #expect(NotificationSettingsRules.notice(for: .denied) == .denied)
        #expect(NotificationSettingsRules.notice(for: .granted) == .granted)
    }
}
