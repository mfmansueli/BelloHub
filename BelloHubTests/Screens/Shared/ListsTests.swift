//
//  ListsTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

/// The three lists the screens of the slice show, built from the digest: Follow-ups, Win back and Alerts.
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

    private func overdue(_ client: Client, service: Service, daysAgo: Int) -> Appointment {
        var visit = makeVisit(clientID: client.id, start: TestClock.days(-daysAgo), status: .completed)
        visit.serviceID = service.id
        return visit
    }

    // MARK: - Follow-ups

    @Test("Follow-ups lists the most overdue first and the birthdays of the week, soonest first")
    func followUps() {
        let glow = makeService(followUpWeeks: 4)
        let ana = Client(name: "Ana Costa", createdAt: TestClock.days(-300))
        let bea = Client(name: "Beatriz Lima", createdAt: TestClock.days(-300))
        let julia = Client(name: "Julia Mendes", birthday: Birthday(month: 10, day: 4), createdAt: TestClock.days(-300))
        let larissa = Client(
            name: "Larissa Souza", birthday: Birthday(month: 10, day: 2), createdAt: TestClock.days(-300)
        )
        let visits = [overdue(ana, service: glow, daysAgo: 35), overdue(bea, service: glow, daysAgo: 50)]
        let list = FollowUpsList.make(from: digest(visits, clients: [ana, bea, julia, larissa], services: [glow]))

        #expect(list.due.map(\.client.id) == [bea.id, ana.id])
        #expect(list.due.map(\.followUp.serviceName) == ["Glow Facial", "Glow Facial"])
        #expect(list.birthdays.map(\.client.id) == [larissa.id, julia.id])
        #expect(!list.isEmpty)
    }

    @Test("Follow-ups is empty with nobody due and no birthday")
    func followUpsEmpty() {
        let ana = Client(name: "Ana Costa", createdAt: TestClock.days(-300))

        #expect(FollowUpsList.make(from: digest([], clients: [ana])).isEmpty)
    }

    @Test("A client who asked not to be messaged is not due")
    func followUpsStopped() {
        let glow = makeService(followUpWeeks: 4)
        let ana = Client(name: "Ana Costa", remindersEnabled: false, createdAt: TestClock.days(-300))
        let list = FollowUpsList.make(from: digest([overdue(ana, service: glow, daysAgo: 60)], clients: [ana], services: [glow]))

        #expect(list.due.isEmpty)
    }

    // MARK: - Win back

    @Test("Win back lists whoever has been away for two months or more, longest first")
    func winBack() {
        let glow = makeService()
        let ana = Client(name: "Ana Costa", createdAt: TestClock.days(-300))
        let bea = Client(name: "Beatriz Lima", createdAt: TestClock.days(-300))
        let cris = Client(name: "Cristina Alves", createdAt: TestClock.days(-300))
        let visits = [
            overdue(ana, service: glow, daysAgo: 61), overdue(bea, service: glow, daysAgo: 120),
            overdue(cris, service: glow, daysAgo: 59)
        ]
        let list = WinBackList.make(from: digest(visits, clients: [ana, bea, cris]))

        #expect(list.rows.map(\.client.id) == [bea.id, ana.id])
        #expect(list.rows.map(\.candidate.daysSinceLastVisit) == [120, 61])
    }

    @Test("Someone with a visit booked is not in Win back, and an empty list says so")
    func winBackBooked() {
        let glow = makeService()
        let ana = Client(name: "Ana Costa", createdAt: TestClock.days(-300))
        let booked = makeVisit(clientID: ana.id, start: TestClock.days(3))
        let list = WinBackList.make(from: digest([overdue(ana, service: glow, daysAgo: 90), booked], clients: [ana]))

        #expect(list.isEmpty)
    }

    // MARK: - Alerts

    @Test("Alerts gathers the visit that starts soon, the birthdays and the counts")
    func alerts() {
        let glow = makeService(followUpWeeks: 4)
        let ana = Client(name: "Ana Costa", phoneE164: "+5511955550001", createdAt: TestClock.days(-300))
        let bea = Client(name: "Beatriz Lima", createdAt: TestClock.days(-300))
        let larissa = Client(
            name: "Larissa Souza", birthday: Birthday(month: 10, day: 3), createdAt: TestClock.days(-300)
        )
        let soon = makeVisit(clientID: ana.id, start: TestClock.date("2026-10-01 13:00"))
        let list = AlertsList.make(from: digest(
            [soon, overdue(bea, service: glow, daysAgo: 90)], clients: [ana, bea, larissa], services: [glow]
        ))

        #expect(list.upcomingVisit?.id == soon.id)
        #expect(list.remindersReady.map(\.id) == [soon.id])
        #expect(list.birthdays.map(\.client.id) == [larissa.id])
        #expect(list.followUpCount == 1 && list.winBackCount == 1)
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
