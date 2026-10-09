//
//  FakeInboxRepository.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation

/// The inbox server in a test: serves bookings, reschedule requests and the waitlist from tables, changes them the way
/// the server would when she answers, records every write, and fails like the app would offline. Lives only in the
/// tests target; the app's stand-ins are `OfflineInboxRepository` and, in DEBUG, `UITestInboxRepository`.
actor FakeInboxRepository: InboxRepository {
    private(set) var bookings: [IncomingBooking]
    private(set) var requests: [RescheduleRequest]
    private(set) var waitlist: [WaitlistRequest]
    /// Every write fails with this until set back to nil (reads keep working, like a flaky write path).
    private var writeFailure: BookingRepositoryError?
    private var approvalOutcome: BookingRequestOutcome = .confirmed
    private var rescheduleOutcome: RescheduleOutcome?
    private var offerOutcome: WaitlistOfferOutcome = .offered(holdKey: "hold", expiresAt: TestClock.now)
    /// Every write, as `name:argument`, in order.
    private(set) var writes: [String] = []
    private(set) var offers: [WaitlistOffer] = []

    init(
        bookings: [IncomingBooking] = [], requests: [RescheduleRequest] = [], waitlist: [WaitlistRequest] = []
    ) {
        self.bookings = bookings
        self.requests = requests
        self.waitlist = waitlist
    }

    func setWriteFailure(_ error: BookingRepositoryError?) {
        writeFailure = error
    }

    /// What approving a booking request answers (`.needsSubscription` for D42).
    func setApprovalOutcome(_ outcome: BookingRequestOutcome) {
        approvalOutcome = outcome
    }

    /// What accepting a reschedule answers; nil = accepted or declined as asked.
    func setRescheduleOutcome(_ outcome: RescheduleOutcome?) {
        rescheduleOutcome = outcome
    }

    func setOfferOutcome(_ outcome: WaitlistOfferOutcome) {
        offerOutcome = outcome
    }

    // MARK: - Reads

    func bookings(uid: String, since: Date) async throws -> [IncomingBooking] { bookings }
    func rescheduleRequests(uid: String) async throws -> [RescheduleRequest] { requests }
    func waitlist(uid: String) async throws -> [WaitlistRequest] { waitlist }
    func mailboxItems(uid: String) async throws -> [MailboxItem] { [] }
    func mailboxItem(id: String) async throws -> MailboxItem { throw BookingRepositoryError.rejected }

    // MARK: - Writes

    func respondBookingRequest(id: String, approve: Bool) async throws -> BookingRequestOutcome {
        try write("respondBookingRequest:\(id):\(approve)")
        guard let index = bookings.firstIndex(where: { $0.id == id }) else { throw BookingRepositoryError.rejected }
        let outcome: BookingRequestOutcome = approve ? approvalOutcome : .declined
        switch outcome {
        case .confirmed:
            bookings[index].status = .confirmed
            bookings[index].pendingReason = nil
        case .declined: bookings[index].status = .declined
        case .needsSubscription: break
        }
        return outcome
    }

    func respondRescheduleRequest(id: String, accept: Bool) async throws -> RescheduleOutcome {
        try write("respondRescheduleRequest:\(id):\(accept)")
        guard let index = requests.firstIndex(where: { $0.id == id }) else { throw BookingRepositoryError.rejected }
        let outcome = accept ? (rescheduleOutcome ?? .accepted) : .declined
        switch outcome {
        case .accepted: requests[index].status = .accepted
        case .declined: requests[index].status = .declined
        case .slotTaken: break
        }
        return outcome
    }

    func offerWaitlistSlot(_ offer: WaitlistOffer) async throws -> WaitlistOfferOutcome {
        try write("offerWaitlistSlot:\(offer.waitlistId)")
        offers.append(offer)
        if case .offered = offerOutcome, let index = waitlist.firstIndex(where: { $0.id == offer.waitlistId }) {
            waitlist[index].status = .offered
        }
        return offerOutcome
    }

    func removeWaitlistEntry(id: String) async throws {
        try write("removeWaitlistEntry:\(id)")
        waitlist.removeAll { $0.id == id }
    }

    func resetNoShowCount(phone: String) async throws {
        try write("resetNoShowCount:\(phone)")
    }

    func acknowledgeMailboxItem(id: String) async throws {
        try write("acknowledgeMailboxItem:\(id)")
    }

    func registerDevice(fcmToken: String, locale: String?) async throws {
        try write("registerDevice:\(fcmToken)")
    }

    func unregisterDevice(fcmToken: String) async throws {
        try write("unregisterDevice:\(fcmToken)")
    }

    private func write(_ call: String) throws {
        if let writeFailure { throw writeFailure }
        writes.append(call)
    }
}
