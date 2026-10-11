//
//  FollowUpPlannerTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@Suite("FollowUpPlanner")
struct FollowUpPlannerTests {
    private let calendar = TestClock.calendar()
    private let service = makeService(followUpWeeks: 4)

    private func due(_ clients: [Client], _ appointments: [Appointment], now: Date = TestClock.now) -> [FollowUp] {
        FollowUpPlanner.dueFollowUps(clients: clients, appointments: appointments, services: [service], now: now,
                                     calendar: calendar)
    }

    private func visit(_ client: Client, daysAgo: Int) -> Appointment {
        makeAppointment(clientID: client.id, daysFromNow: -daysAgo, serviceID: service.id)
    }

    @Test("The prototype's follow-ups: Beatriz 28 days, Marina 35, Paula 42, most overdue first")
    func prototypeFollowUps() {
        let beatriz = makeClient(name: "Beatriz")
        let marina = makeClient(name: "Marina")
        let paula = makeClient(name: "Paula")
        let result = due([beatriz, marina, paula], [visit(beatriz, daysAgo: 28), visit(marina, daysAgo: 35),
                                                    visit(paula, daysAgo: 42)])

        #expect(result.map(\.clientID) == [paula.id, marina.id, beatriz.id])
        #expect(result.map(\.daysSinceLastVisit) == [42, 35, 28])
    }

    @Test("Due on the exact day, not the day before (4 weeks is 28 days)",
          arguments: [(27, false), (28, true), (29, true)])
    func boundary(daysAgo: Int, isDue: Bool) {
        let client = makeClient()

        #expect(due([client], [visit(client, daysAgo: daysAgo)]).isEmpty == !isDue)
    }

    @Test("Nothing is due while a visit is booked ahead")
    func upcomingSuppresses() {
        let client = makeClient()
        let ahead = makeAppointment(clientID: client.id, daysFromNow: 3, status: .booked)

        #expect(due([client], [visit(client, daysAgo: 40), ahead]).isEmpty)
    }

    @Test("A cancelled future visit does not suppress the follow-up")
    func cancelledFutureDoesNotSuppress() {
        let client = makeClient()
        let cancelled = makeAppointment(clientID: client.id, daysFromNow: 3, status: .cancelled, cancelledBy: .client)

        #expect(due([client], [visit(client, daysAgo: 40), cancelled]).count == 1)
    }

    @Test("Archived clients and clients who asked not to be messaged are left out")
    func notReachable() {
        let archived = makeClient(isArchived: true)
        let silent = makeClient(remindersEnabled: false)

        #expect(due([archived, silent], [visit(archived, daysAgo: 40), visit(silent, daysAgo: 40)]).isEmpty)
    }

    @Test("A service without a follow-up interval never makes a client due")
    func noInterval() {
        let client = makeClient()
        let plain = makeService(followUpWeeks: nil)
        let appointment = makeAppointment(clientID: client.id, daysFromNow: -100, serviceID: plain.id)

        #expect(FollowUpPlanner.dueFollowUps(clients: [client], appointments: [appointment], services: [plain],
                                             now: TestClock.now, calendar: calendar).isEmpty)
    }

    @Test("The last completed visit decides, not an older one")
    func lastVisitDecides() {
        let client = makeClient()
        let recent = visit(client, daysAgo: 10)

        #expect(due([client], [visit(client, daysAgo: 90), recent]).isEmpty)
    }

    @Test("A client who never completed a visit is never due")
    func neverCompleted() {
        let client = makeClient()
        let noShow = makeAppointment(clientID: client.id, daysFromNow: -50, status: .noShow, serviceID: service.id)

        #expect(due([client], [noShow]).isEmpty)
    }

    // MARK: - Win back

    @Test("The prototype's win-back list: Gisele 63 days, Fernanda 84, Tatiana 98, longest away first")
    func prototypeWinBack() {
        let gisele = makeClient(name: "Gisele")
        let fernanda = makeClient(name: "Fernanda")
        let tatiana = makeClient(name: "Tatiana")
        let result = FollowUpPlanner.winBack(
            clients: [gisele, fernanda, tatiana],
            appointments: [visit(gisele, daysAgo: 63), visit(fernanda, daysAgo: 84), visit(tatiana, daysAgo: 98)],
            now: TestClock.now, calendar: calendar
        )

        #expect(result.map(\.clientID) == [tatiana.id, fernanda.id, gisele.id])
        #expect(result.map(\.daysSinceLastVisit) == [98, 84, 63])
    }

    @Test("Win back starts at exactly 60 days", arguments: [(59, false), (60, true)])
    func winBackBoundary(daysAgo: Int, included: Bool) {
        let client = makeClient()
        let result = FollowUpPlanner.winBack(clients: [client], appointments: [visit(client, daysAgo: daysAgo)],
                                             now: TestClock.now, calendar: calendar)

        #expect(result.isEmpty == !included)
    }

    @Test("A client with a booking ahead is not someone to win back")
    func winBackIgnoresUpcoming() {
        let client = makeClient()
        let ahead = makeAppointment(clientID: client.id, daysFromNow: 2, status: .confirmed)

        #expect(FollowUpPlanner.winBack(clients: [client], appointments: [visit(client, daysAgo: 90), ahead],
                                        now: TestClock.now, calendar: calendar).isEmpty)
    }

    @Test("Day counts follow the business calendar across a daylight-saving change")
    func daylightSavingDayCount() {
        // Lisbon springs forward on 2026-03-29. Seven calendar days pass between Mar 25 and Apr 1 even though
        // the span is 167 hours.
        var lisbon = Calendar(identifier: .gregorian)
        lisbon.timeZone = TimeZone(identifier: "Europe/Lisbon") ?? .gmt
        let client = makeClient()
        let last = TestClock.date("2026-03-25 10:00", zone: "Europe/Lisbon")
        let appointment = Appointment(clientID: client.id, serviceID: service.id, serviceName: "Glow Facial",
                                      startsAt: last, endsAt: last.addingTimeInterval(3_600), status: .completed,
                                      createdAt: last)
        let result = FollowUpPlanner.dueFollowUps(clients: [client], appointments: [appointment], services: [service],
                                                  now: TestClock.date("2026-04-22 09:00", zone: "Europe/Lisbon"),
                                                  calendar: lisbon)

        #expect(result.first?.daysSinceLastVisit == 28)
    }

    // MARK: - Birthdays

    @Test("Birthdays this week include today and the next six days, soonest first")
    func birthdaysThisWeek() throws {
        let today = makeClient(name: "Today", birthday: Birthday(month: 10, day: 1))
        let friday = makeClient(name: "Friday", birthday: Birthday(month: 10, day: 2))
        let sevenAway = makeClient(name: "Seven days away", birthday: Birthday(month: 10, day: 8))
        let sixAway = makeClient(name: "Six days away", birthday: Birthday(month: 10, day: 7))
        let archived = makeClient(name: "Archived", isArchived: true, birthday: Birthday(month: 10, day: 2))
        let result = FollowUpPlanner.birthdays(clients: [friday, sixAway, sevenAway, archived, today],
                                               now: TestClock.now, calendar: calendar)

        #expect(result.map(\.clientID) == [today.id, friday.id, sixAway.id])
        #expect(result.first?.isToday == true)
        #expect(result.dropFirst().allSatisfy { !$0.isToday })
    }

    @Test("A year-end week finds a birthday in January")
    func birthdaysAcrossTheYear() {
        let newYear = makeClient(birthday: Birthday(month: 1, day: 2))
        let result = FollowUpPlanner.birthdays(clients: [newYear], now: TestClock.date("2026-12-30 12:00"),
                                               calendar: calendar)

        #expect(result.count == 1)
    }
}
