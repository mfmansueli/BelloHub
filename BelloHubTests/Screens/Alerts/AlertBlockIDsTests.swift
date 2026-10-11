//
//  AlertBlockIDsTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@Suite("AlertBlockIDs")
struct AlertBlockIDsTests {
    @Test("The cards are listed requests first, then the waitlist, the mailbox, the upcoming visit and the queue")
    func order() {
        let inbox = InboxAlerts(
            bookingRequests: [makeIncomingBooking(id: "b1")], reschedules: [makeRescheduleRequest(id: "r1")],
            waitingCount: 2, hasOpenTime: false
        )
        let mailbox = MailboxAlerts(items: [.unopened(id: "m1")], importedCount: 1)

        let ids = AlertBlockIDs.make(list: AlertsList(upcomingVisit: nil), inbox: inbox, mailbox: mailbox, reachOut: 3)

        #expect(ids == ["request.b1", "reschedule.r1", "waitlist", "imported", "mailbox.m1", "reachOut"])
    }

    @Test("Answering a request removes only its card")
    func answered() {
        let both = InboxAlerts(
            bookingRequests: [makeIncomingBooking(id: "a"), makeIncomingBooking(id: "b")], reschedules: [],
            waitingCount: 0, hasOpenTime: false
        )
        let one = InboxAlerts(
            bookingRequests: [makeIncomingBooking(id: "b")], reschedules: [], waitingCount: 0, hasOpenTime: false
        )
        let list = AlertsList(upcomingVisit: nil)

        let before = AlertBlockIDs.make(list: list, inbox: both, mailbox: .empty, reachOut: 0)
        let after = AlertBlockIDs.make(list: list, inbox: one, mailbox: .empty, reachOut: 0)

        #expect(MotionChange.rowChange(from: before, to: after) == .init(inserted: 0, removed: 1, isReorder: false))
    }

    @Test("Nothing to say is no identity at all")
    func empty() {
        #expect(AlertBlockIDs.make(
            list: AlertsList(upcomingVisit: nil), inbox: .empty, mailbox: .empty, reachOut: 0
        ).isEmpty)
    }
}
