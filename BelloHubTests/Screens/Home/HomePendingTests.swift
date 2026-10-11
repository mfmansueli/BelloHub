//
//  HomePendingTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

/// Home's "Today" and its one secondary card (routine-a item 4).
@Suite("HomePending and HomeReachOut")
struct HomePendingTests {
    private func item(_ kind: FollowUpKind, client: UUID) -> FollowUpItem {
        FollowUpItem(
            kind: kind, clientID: client, occurrence: "\(kind):\(client)", due: TestClock.now,
            reason: .notBack(daysSinceLastVisit: 70)
        )
    }

    private func queue(_ rows: [(Client, [FollowUpKind])]) -> FollowUpQueue {
        FollowUpQueue(
            rows: rows.map { client, kinds in
                FollowUpQueue.Row(client: client, items: kinds.map { item($0, client: client.id) })
            },
            setAside: []
        )
    }

    @Test("Requests come first and apart, then reminders and visits to close; notifications only with a visit coming")
    func today() {
        let ana = makeClient(name: "Ana Costa")
        let bea = makeClient(name: "Beatriz Lima")
        let built = queue([(ana, [.reminder, .returnDue]), (bea, [.unfinishedVisit])])

        let pending = HomePending.make(
            queue: built, requestCount: 2, notificationsUndecided: true, hasUpcomingVisit: true
        )
        #expect(pending.items == [.bookingRequests(count: 2), .reminders(count: 1), .unfinishedVisits(count: 1),
                                  .notifications])

        let quiet = HomePending.make(
            queue: queue([]), requestCount: 0, notificationsUndecided: true, hasUpcomingVisit: false
        )
        #expect(quiet.isEmpty)
    }

    @Test("The reach-out card counts check-ins, returns, not back and birthdays, never reminders twice")
    func reachOut() {
        let ana = makeClient(name: "Ana Costa")
        let bea = makeClient(name: "Beatriz Lima")
        let cris = makeClient(name: "Cristina Alves")
        let card = HomeReachOut.make(queue: queue([
            (ana, [.reminder]), (bea, [.returnDue, .notBack]), (cris, [.birthday])
        ]))

        #expect(card.count == 2)
        #expect(card.preview.map(\.client.id) == [bea.id, cris.id])
        #expect(card.preview.first?.items.map(\.kind) == [.returnDue, .notBack])
    }
}
