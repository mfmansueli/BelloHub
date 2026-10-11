//
//  ListsTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

/// The local part of Alerts, built from the digest (the follow-up queue has its own tests).
@Suite("Home slice lists")
struct ListsTests {
    private let days = CalendarDays(timeZone: TestClock.saoPaulo, firstWeekday: 2)

    private func digest(
        _ visits: [Appointment], clients: [Client], services: [Service] = [], now: Date = TestClock.now
    ) -> AgendaDigest {
        AgendaDigest.make(
            AgendaDigest.Input(
                appointments: visits, clients: clients, services: services, blocks: [],
                availability: makeAvailability(), prefs: .standard, now: now
            ),
            days: days
        )
    }

    // MARK: - Alerts

    @Test("Alerts shows the visit that starts soon (the rest is one card about the follow-up queue)")
    func alerts() {
        let ana = Client(name: "Ana Costa", phoneE164: "+5511955550001", createdAt: TestClock.days(-300))
        let soon = makeVisit(clientID: ana.id, start: TestClock.date("2026-10-01 13:00"))
        let list = AlertsList.make(from: digest([soon], clients: [ana]))

        #expect(list.upcomingVisit?.id == soon.id)
        #expect(!list.isEmpty)
    }

    @Test("A visit that is far away or already running is not an upcoming-visit alert",
          arguments: ["15:30", "11:30"])
    func alertsUpcomingWindow(time: String) {
        let ana = Client(name: "Ana Costa", createdAt: TestClock.days(-300))
        let visit = makeVisit(clientID: ana.id, start: TestClock.date("2026-10-01 \(time)"))

        #expect(AlertsList.make(from: digest([visit], clients: [ana])).upcomingVisit == nil)
    }

    @Test("With nothing to say, Alerts is empty")
    func alertsEmpty() {
        #expect(AlertsList.make(from: digest([], clients: [])).isEmpty)
    }
}
