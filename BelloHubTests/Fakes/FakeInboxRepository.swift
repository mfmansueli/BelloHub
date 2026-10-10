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
    /// The sealed mailbox: what `mailboxItems` lists, and the envelopes kept "in Storage" for `mailboxItem(id:)`.
    private(set) var mailbox: [MailboxItem] = []
    private var storedEnvelopes: [String: SealedEnvelope] = [:]
    /// Every read, as `name` (or `name:id`), in order.
    private(set) var reads: [String] = []
    /// Every read fails with this until set back to nil (offline).
    private var readFailure: BookingRepositoryError?

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

    func setReadFailure(_ error: BookingRepositoryError?) {
        readFailure = error
    }

    /// The items the mailbox lists. An item listed without its envelope is served by `mailboxItem(id:)` with the
    /// envelope from `stored` (a large envelope kept in Storage).
    func setMailbox(_ items: [MailboxItem], stored: [String: SealedEnvelope] = [:]) {
        mailbox = items
        storedEnvelopes = stored
    }

    // MARK: - Reads

    func bookings(uid: String, since: Date) async throws -> [IncomingBooking] {
        try read("bookings")
        return bookings
    }

    func rescheduleRequests(uid: String) async throws -> [RescheduleRequest] { requests }
    func waitlist(uid: String) async throws -> [WaitlistRequest] { waitlist }

    func mailboxItems(uid: String) async throws -> [MailboxItem] {
        try read("mailboxItems")
        return mailbox
    }

    func mailboxItem(id: String) async throws -> MailboxItem {
        try read("mailboxItem:\(id)")
        guard var item = mailbox.first(where: { $0.id == id }) else { throw BookingRepositoryError.rejected }
        item.envelope = item.envelope ?? storedEnvelopes[id]
        return item
    }

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

    /// What a suggestion answers; `.suggested` declines the request like the server does.
    private var suggestionOutcome: BookingSuggestionOutcome = .suggested(holdKey: "held", expiresAt: TestClock.now)

    func setSuggestionOutcome(_ outcome: BookingSuggestionOutcome) {
        suggestionOutcome = outcome
    }

    func suggestBookingTime(bookingId: String, startsAt: Date) async throws -> BookingSuggestionOutcome {
        try write("suggestBookingTime:\(bookingId):\(CallableJSON.instant(startsAt))")
        guard let index = bookings.firstIndex(where: { $0.id == bookingId }) else {
            throw BookingRepositoryError.rejected
        }
        if case .suggested = suggestionOutcome { bookings[index].status = .declined }
        return suggestionOutcome
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
        mailbox.removeAll { $0.id == id }
    }

    /// The server's registration counter (D42): counts each new id once, up to `freeLimit` unless `hasPlan`.
    private(set) var registered: [UUID] = []
    private var serverHasPlan = false

    func setServerHasPlan(_ value: Bool) {
        serverHasPlan = value
    }

    func reserveRegistrations(_ claims: [RegistrationClaim]) async throws -> RegistrationReservation {
        try write("reserveRegistrations:\(claims.count)")
        var allowed = Set<UUID>()
        var refused = Set<UUID>()
        for claim in claims {
            if registered.contains(claim.clientID) {
                allowed.insert(claim.clientID)
            } else if serverHasPlan || registered.count < RegistrationQuota.freeLimit {
                registered.append(claim.clientID)
                allowed.insert(claim.clientID)
            } else {
                refused.insert(claim.clientID)
            }
        }
        return RegistrationReservation(allowed: allowed, refused: refused, count: registered.count)
    }

    /// Clients the server counted before this phone knew them (bookings from the link, another device).
    func preRegister(_ ids: [UUID]) {
        registered.append(contentsOf: ids)
    }

    func deleteClientServerData(phone: String?, bookingIds: [String]) async throws {
        try write("deleteClientServerData:\(phone ?? "-"):\(bookingIds.joined(separator: ","))")
        bookings.removeAll { bookingIds.contains($0.id) || $0.client.phone == phone }
    }

    func registerDevice(fcmToken: String, locale: String?) async throws {
        try write("registerDevice:\(fcmToken)")
    }

    func unregisterDevice(fcmToken: String) async throws {
        try write("unregisterDevice:\(fcmToken)")
    }

    private func read(_ call: String) throws {
        reads.append(call)
        if let readFailure { throw readFailure }
    }

    private func write(_ call: String) throws {
        if let writeFailure { throw writeFailure }
        writes.append(call)
    }
}
