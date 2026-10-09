//
//  InboxAlertsTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@Suite("InboxAlerts")
struct InboxAlertsTests {
    @Test("Open requests are listed oldest first; an answered one leaves at once; the waitlist counts the waiting")
    func listsRequests() {
        var older = makeIncomingBooking(id: "older")
        older.createdAt = TestClock.now.addingTimeInterval(-7_200)
        let snapshot = InboxSnapshot(
            bookings: [makeIncomingBooking(id: "newer"), older, makeIncomingBooking(id: "done", status: .confirmed),
                       makeIncomingBooking(id: "answered")],
            rescheduleRequests: [makeRescheduleRequest(id: "rr-open"),
                                 makeRescheduleRequest(id: "rr-done", status: .declined)],
            waitlist: [makeWaitlistRequest(id: "a"), makeWaitlistRequest(id: "b", status: .booked)]
        )
        let alerts = InboxAlerts.make(
            snapshot: snapshot, answering: ["answered"], timeZone: TestClock.saoPaulo, now: TestClock.now
        )
        #expect(alerts.bookingRequests.map(\.id) == ["older", "newer"])
        #expect(alerts.reschedules.map(\.id) == ["rr-open"])
        #expect(alerts.waitingCount == 1 && !alerts.hasOpenTime && !alerts.isEmpty)
    }

    @Test("A cancelled time with somebody to offer it to is an open time")
    func openTime() {
        let snapshot = InboxSnapshot(
            bookings: [makeIncomingBooking(id: "bk-c", status: .cancelledByClient, daysAhead: 3)],
            waitlist: [makeWaitlistRequest(id: "a")]
        )
        let alerts = InboxAlerts.make(
            snapshot: snapshot, answering: [], timeZone: TestClock.saoPaulo, now: TestClock.now
        )
        #expect(alerts.hasOpenTime && alerts.waitingCount == 1)
    }

    @Test("Nothing from the server is empty")
    func empty() {
        #expect(InboxAlerts.make(snapshot: InboxSnapshot(), answering: [], timeZone: .gmt, now: TestClock.now).isEmpty)
        #expect(InboxAlerts.empty.isEmpty)
    }
}
