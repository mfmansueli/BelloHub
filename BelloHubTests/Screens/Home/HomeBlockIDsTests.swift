//
//  HomeBlockIDsTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

/// The identities Home's rows animate by (`motionRows`): a confirmed, moved or cancelled visit is a different list.
@Suite("HomeBlockIDs")
struct HomeBlockIDsTests {
    private let days = CalendarDays(timeZone: TestClock.saoPaulo, firstWeekday: 2)

    private func digest(_ visits: [Appointment], clients: [Client]) -> AgendaDigest {
        AgendaDigest.make(
            AgendaDigest.Input(
                appointments: visits, clients: clients, services: [], blocks: [],
                availability: makeAvailability(), prefs: .standard, now: TestClock.now
            ),
            days: days
        )
    }

    private let noPending = HomePending(items: [])
    private let noReachOut = HomeReachOut(count: 0, preview: [])

    @Test("A clear day is one block")
    func clearDay() {
        let ids = HomeBlockIDs.make(digest: digest([], clients: []), pending: noPending, reachOut: noReachOut)

        #expect(ids == ["empty"])
    }

    @Test("The next visit leads, then the lines of Today, the rest of today and the people to reach out to")
    func order() {
        let ana = makeClient(name: "Ana Costa")
        let first = makeVisit(clientID: ana.id, start: TestClock.date("2026-10-01 13:00"))
        let second = makeVisit(clientID: ana.id, start: TestClock.date("2026-10-01 15:00"))
        let pending = HomePending(items: [.reminders(count: 2)])
        let reach = HomeReachOut(count: 1, preview: [FollowUpQueue.Row(client: ana, items: [])])

        let ids = HomeBlockIDs.make(
            digest: digest([second, first], clients: [ana]), pending: pending, reachOut: reach
        )

        #expect(ids == [
            "next.\(first.id.uuidString)", "today.reminders", "rest.\(second.id.uuidString)",
            "reachOut.\(ana.id.uuidString)"
        ])
    }

    @Test("A cancelled visit leaves the list, so exactly that identity is removed")
    func cancelledLeaves() {
        let ana = makeClient(name: "Ana Costa")
        let first = makeVisit(clientID: ana.id, start: TestClock.date("2026-10-01 13:00"))
        let second = makeVisit(clientID: ana.id, start: TestClock.date("2026-10-01 15:00"))
        let before = HomeBlockIDs.make(
            digest: digest([first, second], clients: [ana]), pending: noPending, reachOut: noReachOut
        )
        var cancelled = second
        cancelled.status = .cancelledByPro
        let after = HomeBlockIDs.make(
            digest: digest([first, cancelled], clients: [ana]), pending: noPending, reachOut: noReachOut
        )

        let change = MotionChange.rowChange(from: before, to: after)

        #expect(change == .init(inserted: 0, removed: 1, isReorder: false))
    }
}
