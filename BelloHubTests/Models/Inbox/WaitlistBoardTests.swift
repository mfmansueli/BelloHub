//
//  WaitlistBoardTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@Suite("WaitlistBoard")
struct WaitlistBoardTests {
    private let zone = TestClock.saoPaulo

    private func makeSnapshot(bookings: [IncomingBooking] = [], waitlist: [WaitlistRequest]) -> InboxSnapshot {
        InboxSnapshot(bookings: bookings, waitlist: waitlist)
    }

    @Test("With no cancelled time, everybody still waiting is listed, oldest first, and nothing can be offered")
    func noOpenTime() {
        let board = WaitlistBoard.make(
            snapshot: makeSnapshot(waitlist: [
                makeWaitlistRequest(id: "new", daysAgo: 1), makeWaitlistRequest(id: "old", daysAgo: 5),
                makeWaitlistRequest(id: "offered", status: .offered), makeWaitlistRequest(id: "booked", status: .booked)
            ]),
            timeZone: zone, now: TestClock.now
        )
        #expect(board.openTime == nil)
        #expect(board.forThatDay.isEmpty && board.offerable.isEmpty)
        #expect(board.others.map(\.id) == ["old", "new"])
    }

    @Test("A future cancellation is the open time; people whose days cover it are listed for that day")
    func openTimeAndThatDay() throws {
        let cancelled = makeIncomingBooking(id: "bk-c", status: .cancelledByClient, daysAhead: 3, hour: 15)
        let board = WaitlistBoard.make(
            snapshot: makeSnapshot(bookings: [cancelled], waitlist: [
                makeWaitlistRequest(id: "covers", from: "2026-10-01", until: "2026-10-08"),
                makeWaitlistRequest(id: "offered", from: "2026-10-04", until: "2026-10-04", status: .offered),
                makeWaitlistRequest(id: "later", from: "2026-10-10", until: "2026-10-12")
            ]),
            timeZone: zone, now: TestClock.now
        )
        let open = try #require(board.openTime)
        #expect(open.bookingID == "bk-c" && open.serviceID == "svc-glow" && open.minutes == 90)
        #expect(open.clientName == "Ana Costa")
        #expect(board.forThatDay.map(\.id) == ["covers", "offered"])
        #expect(board.offerable.map(\.id) == ["covers"], "an offered person is not offered twice")
        #expect(board.others.map(\.id) == ["later"])
    }

    @Test("A past cancellation, or one whose time a new booking took, is not open; the earliest open one wins")
    func whichCancellationIsOpen() {
        let past = makeIncomingBooking(id: "past", status: .cancelledByClient, daysAhead: -1)
        let retaken = makeIncomingBooking(id: "retaken", status: .cancelledByPro, daysAhead: 2, hour: 10)
        let taker = makeIncomingBooking(id: "taker", status: .confirmed, daysAhead: 2, hour: 11)
        let later = makeIncomingBooking(id: "later", status: .cancelledByClient, daysAhead: 5)
        let sooner = makeIncomingBooking(id: "sooner", status: .cancelledByClient, daysAhead: 4)
        #expect(WaitlistBoard.openTime(in: [past, retaken, taker, later, sooner], now: TestClock.now)?.bookingID
                == "sooner")
        #expect(WaitlistBoard.openTime(in: [past, retaken, taker], now: TestClock.now) == nil)
    }

    @Test("The day of the open time is read in the business time zone, not in UTC")
    func dayInBusinessZone() {
        // 22:30 in São Paulo on Oct 1 is already Oct 2 in UTC.
        let lateEvening = TestClock.date("2026-10-01 22:30")
        #expect(WaitlistBoard.dayKey(lateEvening, timeZone: zone) == "2026-10-01")
        #expect(WaitlistBoard.dayKey(lateEvening, timeZone: .gmt) == "2026-10-02")
    }
}
