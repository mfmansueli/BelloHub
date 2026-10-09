//
//  CalendarVisitTextTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@Suite("CalendarVisitText and CalendarSettings")
struct CalendarVisitTextTests {
    private let formatters = Formatters(
        locale: Locale(identifier: "en_US"), timeZone: TestClock.saoPaulo, currencyCode: "BRL", firstWeekday: 2
    )

    @Test("The span is written the locale's way, in the business zone")
    func span() {
        let visit = makeVisit(start: friday("15:00"), minutes: 90)
        let text = CalendarVisitText(formatters: formatters).span(visit)
        #expect(text.contains("3:00") && text.contains("4:30"))
    }

    @Test("VoiceOver reads client, service, day, time and status for a visit")
    func accessibility() {
        var visit = makeVisit(start: friday("15:00"), minutes: 90, status: .confirmed, serviceName: "Brazilian Glow")
        visit.status = .confirmed
        let label = CalendarVisitText(formatters: formatters).accessibilityLabel(for: visit, clientName: "Ana Costa")
        for part in ["Ana Costa", "Brazilian Glow", "Friday", "October 2", "3:00", "Confirmed"] {
            #expect(label.contains(part), "\(part) is missing from \(label)")
        }
    }

    @Test("A visit whose client cannot be found is read as a client, never an empty name")
    func unknownClient() {
        let visit = makeVisit(start: friday("15:00"))
        let label = CalendarVisitText(formatters: formatters).accessibilityLabel(for: visit, clientName: "")
        #expect(label.hasPrefix("Client,"))
    }

    @Test("A free hour says what a tap does")
    func addLabel() {
        let label = CalendarVisitText(formatters: formatters).addLabel(at: friday("10:00"))
        #expect(label.contains("10:00") && label.lowercased().contains("add"))
    }

    @Test("Every status has words, and a cancelled visit is not drawn in a status color of its own")
    func statuses() {
        let text = CalendarVisitText(formatters: formatters)
        for status in [AppointmentStatus.booked, .confirmed, .completed, .cancelled, .noShow] {
            #expect(!String(localized: text.statusTitle(status)).isEmpty)
        }
    }

    @Test("The calendar settings read the business zone, the region's first weekday and the currency")
    func settings() {
        let profile = ProfessionalProfile(
            displayName: "Maria", regionCode: "US", timeZoneID: "America/New_York", currencyCode: "USD",
            appLocaleID: "en", createdAt: TestClock.now
        )
        let settings = CalendarSettings(profile: profile)
        #expect(settings.timeZoneID == "America/New_York")
        #expect(settings.firstWeekday == 1)
        #expect(settings.currencyCode == "USD")
        let formatters = settings.formatters(locale: Locale(identifier: "en_US"))
        #expect(formatters.timeZone.identifier == "America/New_York")
        #expect(formatters.calendar.firstWeekday == 1)
    }

    @Test("Without a profile the fallback zone is used and the week starts on Monday")
    func fallback() {
        let settings = CalendarSettings(profile: nil, fallbackTimeZoneID: "Europe/Lisbon")
        #expect(settings.timeZoneID == "Europe/Lisbon" && settings.firstWeekday == 2)
    }
}
