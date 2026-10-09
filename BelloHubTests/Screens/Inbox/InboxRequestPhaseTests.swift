//
//  InboxRequestPhaseTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@Suite("InboxRequestPhase")
struct InboxRequestPhaseTests {
    @Test("An unknown booking is loading until the first sync, then missing")
    func unknown() {
        #expect(InboxRequestPhase.booking(nil, isLoading: true, isSending: false, needsPlan: false) == .loading)
        #expect(InboxRequestPhase.booking(nil, isLoading: false, isSending: false, needsPlan: false) == .missing)
    }

    @Test("A booking's status maps to what the screen shows",
          arguments: [(IncomingBookingStatus.pendingApproval, InboxRequestPhase.open), (.confirmed, .accepted),
                      (.completed, .accepted), (.noShow, .accepted), (.declined, .declined),
                      (.cancelledByClient, .withdrawn), (.cancelledByPro, .withdrawn)])
    func bookingStatuses(status: IncomingBookingStatus, phase: InboxRequestPhase) {
        let booking = makeIncomingBooking(status: status)
        #expect(InboxRequestPhase.booking(booking, isLoading: false, isSending: false, needsPlan: false) == phase)
    }

    @Test("An answer on its way wins over the status, and a plan is needed only while the request is open")
    func sendingAndPlan() {
        let open = makeIncomingBooking()
        #expect(InboxRequestPhase.booking(open, isLoading: false, isSending: true, needsPlan: true) == .sending)
        #expect(InboxRequestPhase.booking(open, isLoading: false, isSending: false, needsPlan: true) == .needsPlan)
        let confirmed = makeIncomingBooking(status: .confirmed)
        #expect(InboxRequestPhase.booking(confirmed, isLoading: false, isSending: false, needsPlan: true) == .accepted)
    }

    @Test("A reschedule request maps its status, and a taken time keeps the request answerable")
    func reschedule() {
        let pending = makeRescheduleRequest()
        #expect(InboxRequestPhase.reschedule(pending, isLoading: false, isSending: false, slotTaken: false) == .open)
        #expect(InboxRequestPhase.reschedule(pending, isLoading: false, isSending: false, slotTaken: true)
                == .slotTaken)
        #expect(InboxRequestPhase.reschedule(pending, isLoading: false, isSending: true, slotTaken: true) == .sending)
        #expect(InboxRequestPhase.reschedule(makeRescheduleRequest(status: .accepted), isLoading: false,
                                             isSending: false, slotTaken: false) == .accepted)
        #expect(InboxRequestPhase.reschedule(makeRescheduleRequest(status: .cancelled), isLoading: false,
                                             isSending: false, slotTaken: false) == .withdrawn)
        #expect(InboxRequestPhase.reschedule(nil, isLoading: false, isSending: false, slotTaken: false) == .missing)
        #expect(InboxRequestPhase.slotTaken.canAnswer && InboxRequestPhase.needsPlan.canAnswer)
        #expect(!InboxRequestPhase.sending.canAnswer && !InboxRequestPhase.accepted.canAnswer)
    }
}
