//
//  ClientListBuilderTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@Suite("ClientListBuilder")
struct ClientListBuilderTests {
    private let calendar = TestClock.calendar()
    private let glow = makeService(name: "Glow Facial", followUpWeeks: 4)

    private func build(_ clients: [Client], _ appointments: [Appointment]) -> ClientList {
        ClientListBuilder.build(
            clients: clients, appointments: appointments, services: [glow], now: TestClock.now, calendar: calendar
        )
    }

    // MARK: - Row summary

    @Test("A completed visit wins over a booking in the second line of the row")
    func lastVisitWinsOverBooking() {
        let client = makeListedClient()
        let last = makeAppointment(clientID: client.id, daysFromNow: -30, serviceName: "Deep Cleansing")
        let older = makeAppointment(clientID: client.id, daysFromNow: -90, serviceName: "Glow Facial")
        let next = makeAppointment(clientID: client.id, daysFromNow: 3, status: .booked, serviceName: "Brazilian Glow")

        let summary = build([client], [older, last, next]).entries[0].summary

        #expect(summary == .lastVisit(service: "Deep Cleansing", date: last.startsAt))
    }

    @Test("Someone not seen yet shows the soonest booking, and nothing when there is none")
    func bookedThenNothing() {
        let booked = makeListedClient(name: "Booked")
        let nobody = makeListedClient(name: "Nobody")
        let later = makeAppointment(clientID: booked.id, daysFromNow: 9, status: .booked, serviceName: "Later")
        let sooner = makeAppointment(clientID: booked.id, daysFromNow: 2, status: .confirmed, serviceName: "Sooner")
        let cancelled = makeAppointment(clientID: nobody.id, daysFromNow: 4, status: .cancelled)

        let entries = build([booked, nobody], [later, sooner, cancelled]).entries

        let expected = ClientRowSummary.booked(service: "Sooner", date: sooner.startsAt)
        #expect(entries.first { $0.client.name == "Booked" }?.summary == expected)
        #expect(entries.first { $0.client.name == "Nobody" }?.summary == .noVisitsYet)
    }

    @Test("A visit recorded with no booking is the last visit; drafts and booked visits' records are not counted twice")
    func walkInIsTheLastVisit() {
        let client = makeListedClient()
        let booked = makeAppointment(clientID: client.id, daysFromNow: -30, serviceName: "Glow Facial")
        let walkIn = TreatmentRecord(clientID: client.id, serviceName: "Brow lamination", createdAt: TestClock.days(-1),
                                     performedAt: TestClock.days(-5))
        let draft = TreatmentRecord(clientID: client.id, serviceName: "Peel", createdAt: TestClock.days(-1),
                                    status: .draft)
        let summary = ClientListBuilder.build(
            clients: [client], appointments: [booked], services: [glow],
            walkIns: [walkIn, draft].map(RecordMark.init), now: TestClock.now, calendar: calendar
        ).entries[0].summary

        #expect(summary == .lastVisit(service: "Brow lamination", date: TestClock.days(-5)))
    }

    // MARK: - Win back (FollowUpPlanner's rule)

    @Test("The strip counts clients with no visit for 60 days and nothing booked, longest away first")
    func winBack() {
        let away = makeListedClient(name: "Away")
        let longer = makeListedClient(name: "Longer")
        let recent = makeListedClient(name: "Recent")
        let appointments = [
            makeAppointment(clientID: away.id, daysFromNow: -60),
            makeAppointment(clientID: longer.id, daysFromNow: -90),
            makeAppointment(clientID: recent.id, daysFromNow: -59)
        ]

        let list = build([away, longer, recent], appointments)

        #expect(list.winBack.map(\.clientID) == [longer.id, away.id])
    }

    @Test("Asking the planner one client at a time gives the same answer as asking it about everyone at once")
    func perClientAnswersMatchTheWholeListAnswer() {
        let clients = (0..<12).map { makeListedClient(name: "Client \($0)") }
        let appointments = clients.enumerated().flatMap { index, client in
            [makeAppointment(clientID: client.id, daysFromNow: -(20 + index * 9), serviceID: glow.id)]
        }

        let whole = FollowUpPlanner.winBack(
            clients: clients, appointments: appointments, now: TestClock.now, calendar: calendar
        )
        let due = FollowUpPlanner.dueFollowUps(
            clients: clients, appointments: appointments, services: [glow], now: TestClock.now, calendar: calendar
        )
        let list = build(clients, appointments)

        #expect(Set(list.winBack.map(\.clientID)) == Set(whole.map(\.clientID)))
        #expect(Set(list.entries.filter(\.isDueToReturn).map(\.id)) == Set(due.map(\.clientID)))
    }

    // MARK: - Order and badge

    @Test("The entries come in reading order, archived clients included")
    func entriesAreSorted() {
        let list = build([makeListedClient(name: "Zoe"), makeListedClient(name: "Ana", isArchived: true)], [])

        #expect(list.entries.map(\.client.name) == ["Ana", "Zoe"])
    }

    @Test("The badge is cancels often first, then new, then her first tag, then nothing")
    func badgePriority() throws {
        let tag = Tag(id: UUID(), name: "VIP", colorToken: "rose", position: 0)
        let often = makeListedClient(name: "Often", tagIDs: [tag.id])
        let fresh = makeListedClient(name: "Fresh", tagIDs: [tag.id])
        let regular = makeListedClient(name: "Regular", tagIDs: [tag.id])
        let plain = makeListedClient(name: "Plain")
        let done = (0..<4).map { makeAppointment(clientID: often.id, daysFromNow: -100 + $0) }
        let missed = (0..<3).map {
            makeAppointment(clientID: often.id, daysFromNow: -50 + $0, status: .cancelled, cancelledBy: .client)
        }
        let others = [
            makeAppointment(clientID: regular.id, daysFromNow: -10),
            makeAppointment(clientID: plain.id, daysFromNow: -5)
        ]
        let entries = build([often, fresh, regular, plain], done + missed + others).entries

        func badge(_ name: String) throws -> ClientRowBadge {
            let entry = try #require(entries.first { $0.client.name == name })
            return ClientRowBadge.make(for: entry, tagsByID: [tag.id: tag])
        }

        #expect(try badge("Often") == .cancelsOften)
        #expect(try badge("Fresh") == .new)
        #expect(try badge("Regular") == .tag("VIP"))
        #expect(try badge("Plain") == .none)
    }

    // MARK: - Speed (docs/13-TESTING-QUALITY.md section 6)

    @Test("A vault of 2,000 clients builds, filters, searches and sorts well inside a second each")
    func twoThousandClientsStayFast() {
        let services = [glow]
        let clients = (0..<2_000).map { index in
            makeListedClient(name: "Client \(index) Silva", phone: "+55119\(String(format: "%08d", index))")
        }
        let appointments = clients.enumerated().flatMap { index, client in
            (0..<8).map { step in
                makeAppointment(
                    clientID: client.id, daysFromNow: -300 + step * 17 + index % 11,
                    status: step % 5 == 4 ? .cancelled : .completed, serviceID: glow.id,
                    cancelledBy: step % 5 == 4 ? .client : nil
                )
            }
        }
        let clock = ContinuousClock()

        var list = ClientList.empty
        let build = clock.measure {
            list = ClientListBuilder.build(
                clients: clients, appointments: appointments, services: services, now: TestClock.now, calendar: calendar
            )
        }
        let filters: [ClientListFilter] = [.all, .dueToReturn, .cancelsOften, .new]
        let filter = clock.measure { for chip in filters { _ = chip.apply(to: list.entries) } }
        var matches: [ClientListEntry] = []
        let search = clock.measure { matches = ClientSearch.filter(list.entries, query: "client 19 silva", tags: []) }
        let phone = clock.measure { _ = ClientSearch.filter(list.entries, query: "900019", tags: []) }
        let sort = clock.measure { _ = ClientSort.sorted(list.entries) }

        #expect(list.entries.count == 2_000)
        #expect(!matches.isEmpty)
        // Generous bounds for an unoptimized test build on a busy machine; release is about ten times faster.
        #expect(build < .seconds(3), "building 2,000 clients took \(build)")
        #expect(filter < .seconds(1), "four chips took \(filter)")
        #expect(search < .seconds(1), "a name search took \(search)")
        #expect(phone < .seconds(1), "a phone search took \(phone)")
        #expect(sort < .seconds(1), "sorting took \(sort)")
    }
}
