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

    /// The server changed a booking by itself (the client acted on her manage page): replaces it, or adds it.
    func replace(_ booking: IncomingBooking) {
        if let index = bookings.firstIndex(where: { $0.id == booking.id }) {
            bookings[index] = booking
        } else {
            bookings.append(booking)
        }
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
        return bookings.filter { !unlisted.contains($0.id) }
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

    /// `https://bellohub.app/m/Link<bookingId>…`, valid a week; a write failure makes it fail like the server.
    func mintManageLink(bookingId: String) async throws -> ClientManageLink {
        try write("mintManageLink:\(bookingId)")
        let token = String(("Link" + bookingId + String(repeating: "0", count: 22)).prefix(22))
        let url = URL(string: "https://bellohub.app/m/\(token)") ?? URL(filePath: "/")
        return ClientManageLink(url: url, expiresAt: TestClock.now.addingTimeInterval(7 * 86_400))
    }

    func removeWaitlistEntry(id: String) async throws {
        try write("removeWaitlistEntry:\(id)")
        waitlist.removeAll { $0.id == id }
    }

    func resetNoShowCount(phone: String) async throws {
        try write("resetNoShowCount:\(phone)")
    }

    /// Bookings `bookings(uid:since:)` leaves out, as if they sat outside the window (still served by id).
    private var unlisted: Set<String> = []

    func setUnlisted(_ ids: Set<String>) {
        unlisted = ids
    }

    func booking(uid: String, id: String) async throws -> IncomingBooking? {
        try read("booking:\(id)")
        return bookings.first { $0.id == id }
    }

    func cancelBookingByOwner(id: String) async throws {
        try write("cancelBookingByOwner:\(id)")
        try changeActive(id) {
            $0.status = .cancelledByPro
            $0.cancelledBy = "professional"
            $0.cancelledAt = TestClock.now
            $0.isLateCancellation = false
        }
    }

    func moveBookingByOwner(id: String, startsAt: Date) async throws {
        try write("moveBookingByOwner:\(id):\(CallableJSON.instant(startsAt))")
        try changeActive(id) {
            $0.endsAt = startsAt.addingTimeInterval($0.endsAt.timeIntervalSince($0.startsAt))
            $0.startsAt = startsAt
            $0.clientConfirmedAt = nil
            $0.lateByMinutes = nil
        }
    }

    func markNoShow(phone: String, markId: UUID, markedAt: Date, bookingId: String) async throws {
        try write("markNoShow:mark:\(phone):\(bookingId)")
        if let index = bookings.firstIndex(where: { $0.id == bookingId && $0.status == .confirmed }) {
            bookings[index].status = .noShow
            bookings[index].updatedAt = TestClock.now
        }
    }

    func forgiveNoShow(phone: String, markId: UUID) async throws {
        try write("markNoShow:forgive:\(phone)")
    }

    /// Like the server: a booking that no longer holds time is `BOOKING_NOT_ACTIVE` (`rejected`).
    private func changeActive(_ id: String, _ change: (inout IncomingBooking) -> Void) throws {
        guard let index = bookings.firstIndex(where: { $0.id == id }), bookings[index].status.holdsTime else {
            throw BookingRepositoryError.rejected
        }
        change(&bookings[index])
        bookings[index].updatedAt = TestClock.now
    }

    func acknowledgeMailboxItem(id: String) async throws {
        try write("acknowledgeMailboxItem:\(id)")
        mailbox.removeAll { $0.id == id }
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
