//
//  ClientListFilterTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

/// The chips of the client list. "Cancels often" and its four-visit threshold are `HabitsCalculator`'s and "due to
/// return" is `FollowUpPlanner`'s: these tests pin that the chips agree with them at the exact boundaries instead of
/// restating the numbers.
@Suite("ClientListFilter")
struct ClientListFilterTests {
    private let calendar = TestClock.calendar()
    private let glow = makeService(name: "Glow Facial", followUpWeeks: 4)

    private func list(_ clients: [Client], _ appointments: [Appointment] = []) -> ClientList {
        ClientListBuilder.build(
            clients: clients, appointments: appointments, services: [glow], now: TestClock.now, calendar: calendar
        )
    }

    private func names(_ filter: ClientListFilter, in list: ClientList) -> [String] {
        filter.apply(to: list.entries).map(\.client.name)
    }

    /// `completed` visits then `cancelled` cancellations by the client, all in the past, one a day.
    private func history(for client: Client, completed: Int, cancelled: Int, by who: CancelledBy = .client)
        -> [Appointment] {
        let done = (0..<completed).map { makeAppointment(clientID: client.id, daysFromNow: -120 + $0) }
        let missed = (0..<cancelled).map {
            makeAppointment(
                clientID: client.id, daysFromNow: -60 + $0, status: .cancelled, serviceName: "Glow Facial",
                cancelledBy: who
            )
        }
        return done + missed
    }

    // MARK: - All and archived

    @Test("Every chip but Archived leaves archived clients out, and Archived shows only them")
    func archivedClientsLeaveEveryChip() {
        let active = makeListedClient(name: "Ana")
        let archived = makeListedClient(name: "Beatriz", isArchived: true)
        let result = list([active, archived])

        #expect(names(.all, in: result) == ["Ana"])
        #expect(names(.new, in: result) == ["Ana"])
        #expect(names(.archived, in: result) == ["Beatriz"])
        #expect(result.hasArchived)
    }

    // MARK: - Cancels often (HabitsCalculator's rule)

    @Test("Cancels often needs four completed visits: three is never enough, four with a high rate is")
    func fourVisitThreshold() {
        let three = makeListedClient(name: "Three visits")
        let four = makeListedClient(name: "Four visits")
        let appointments = history(for: three, completed: 3, cancelled: 3)
            + history(for: four, completed: 4, cancelled: 2)
        let result = list([three, four], appointments)

        #expect(names(.cancelsOften, in: result) == ["Four visits"])
        for entry in result.entries {
            let habits = HabitsCalculator.habits(
                for: entry.client.id, appointments: appointments, now: TestClock.now, calendar: calendar
            )
            #expect(entry.habits == habits, "the list shows what HabitsCalculator says for \(entry.client.name)")
        }
    }

    @Test("Cancels often starts at exactly 30 percent of the last ten and not a cancellation below it")
    func thirtyPercentBoundary() {
        let exactly = makeListedClient(name: "Three of ten")
        let below = makeListedClient(name: "Two of ten")
        let appointments = history(for: exactly, completed: 7, cancelled: 3)
            + history(for: below, completed: 8, cancelled: 2)
        let result = list([exactly, below], appointments)

        #expect(names(.cancelsOften, in: result) == ["Three of ten"])
    }

    @Test("A cancellation made by the professional never makes a client cancel often")
    func professionalCancellationsDoNotCount() {
        let client = makeListedClient(name: "Cancelled by Maria")
        let result = list([client], history(for: client, completed: 4, cancelled: 6, by: .professional))

        #expect(names(.cancelsOften, in: result).isEmpty)
    }

    // MARK: - New

    @Test("New means no completed visit yet, with or without something booked")
    func newMeansNoCompletedVisit() {
        let fresh = makeListedClient(name: "Fresh")
        let booked = makeListedClient(name: "Booked")
        let regular = makeListedClient(name: "Regular")
        let appointments = [
            makeAppointment(clientID: booked.id, daysFromNow: 3, status: .booked),
            makeAppointment(clientID: regular.id, daysFromNow: -10)
        ]
        let result = list([fresh, booked, regular], appointments)

        #expect(names(.new, in: result) == ["Booked", "Fresh"])
    }

    // MARK: - Due to return (FollowUpPlanner's rule)

    @Test("Due to return follows the service's follow-up weeks: 28 days is due, 27 is not")
    func dueToReturnBoundary() {
        let due = makeListedClient(name: "Twenty-eight days")
        let notYet = makeListedClient(name: "Twenty-seven days")
        let appointments = [
            makeAppointment(clientID: due.id, daysFromNow: -28, serviceID: glow.id),
            makeAppointment(clientID: notYet.id, daysFromNow: -27, serviceID: glow.id)
        ]
        let result = list([due, notYet], appointments)

        #expect(names(.dueToReturn, in: result) == ["Twenty-eight days"])
    }

    @Test("Someone with something booked, or who asked not to be messaged, is not due to return")
    func dueToReturnLeavesOutTheBookedAndTheUnreachable() {
        let booked = makeListedClient(name: "Booked")
        var silent = makeListedClient(name: "Silent")
        silent.remindersEnabled = false
        let appointments = [
            makeAppointment(clientID: booked.id, daysFromNow: -40, serviceID: glow.id),
            makeAppointment(clientID: booked.id, daysFromNow: 5, status: .booked, serviceID: glow.id),
            makeAppointment(clientID: silent.id, daysFromNow: -40, serviceID: glow.id)
        ]

        #expect(names(.dueToReturn, in: list([booked, silent], appointments)).isEmpty)
    }

    // MARK: - Tags and the chip list

    @Test("A tag chip shows the clients that carry the tag")
    func tagChip() {
        let sensitive = UUID()
        let vip = UUID()
        let result = list([
            makeListedClient(name: "Ana", tagIDs: [sensitive, vip]),
            makeListedClient(name: "Beatriz", tagIDs: [vip]),
            makeListedClient(name: "Camila")
        ])

        #expect(names(.tag(sensitive), in: result) == ["Ana"])
        #expect(names(.tag(vip), in: result) == ["Ana", "Beatriz"])
    }

    @Test("The chips are the four fixed ones, the tags in her order, and Archived only while someone is archived")
    func chipOrder() {
        let first = Tag(id: UUID(), name: "VIP", colorToken: "rose", position: 0)
        let second = Tag(id: UUID(), name: "Bridal", colorToken: "sage", position: 1)

        #expect(
            ClientListFilter.chips(tags: [second, first], hasArchived: false)
                == [.all, .dueToReturn, .cancelsOften, .new, .tag(first.id), .tag(second.id)]
        )
        #expect(ClientListFilter.chips(tags: [], hasArchived: true).last == .archived)
    }

    @Test("Chip identifiers are stable and distinct")
    func identifiers() {
        let tag = UUID()
        let filters: [ClientListFilter] = [.all, .dueToReturn, .cancelsOften, .new, .archived, .tag(tag)]

        #expect(Set(filters.map(\.identifier)).count == filters.count)
        #expect(ClientListFilter.tag(tag).identifier == "tag.\(tag.uuidString)")
    }
}
