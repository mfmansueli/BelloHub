//
//  UITestInboxRepository.swift
//  BelloHub
//

#if DEBUG
import CryptoKit
import Foundation
import UIKit

/// An in-memory inbox server for UI tests (`-uiInbox fixtures`): the data of `UITestInboxFixtures` plus one sealed
/// health form for Helena, sealed at first read to the test key (`InMemoryKeyStore` seed), so the whole
/// open-and-import path runs on the simulator. Answers change the data like the server would. DEBUG only.
///
/// `-uiInbox paywall` makes the approval answer `needsSubscription` (D42). `-uiInbox unverified` makes Ana's request
/// one made without the e-mail code ("Confirm on WhatsApp", verify-fallback). `-uiInbox linkVisit` serves only Bianca's
/// confirmed booking; `-uiInbox clientOnTheWeb` also moves and then cancels it on the server each time the app leaves
/// the foreground, as the client did on her manage page while the owner was away (fix-booking-status).
///
/// An actor, not a @MainActor class: `InboxRepository` is Sendable and the services call it from nonisolated tasks.
actor UITestInboxRepository: InboxRepository {
    enum Scenario: String {
        case fixtures
        case paywall
        case unverified
        case linkVisit
        case clientOnTheWeb

        /// Only Bianca's booking: Home's next visit is hers, nothing else arrives.
        var isLinkVisitOnly: Bool { self == .linkVisit || self == .clientOnTheWeb }
    }

    private let scenario: Scenario
    private let publicKey: @Sendable @MainActor () throws -> InboxPublicKey
    private let now: Date
    private var bookings: [IncomingBooking]
    private var requests: [RescheduleRequest]
    private var waitlist: [WaitlistRequest]
    private var items: [MailboxItem] = []
    private var sealed = false
    private(set) var acknowledged: [String] = []
    private(set) var devices: [String] = []

    init(
        scenario: Scenario, publicKey: @escaping @Sendable @MainActor () throws -> InboxPublicKey,
        now: Date = Date()
    ) {
        self.scenario = scenario
        self.publicKey = publicKey
        self.now = now
        if scenario.isLinkVisitOnly {
            bookings = [UITestInboxFixtures.linkVisit(now: now)]
            requests = []
            waitlist = []
        } else {
            bookings = UITestInboxFixtures.bookings(now: now, unverified: scenario == .unverified)
            requests = UITestInboxFixtures.requests(now: now)
            waitlist = UITestInboxFixtures.waitlist(now: now)
        }
    }

    /// `clientOnTheWeb`: whenever the app leaves the foreground, the client moves Bianca's booking and cancels it.
    nonisolated func actOnTheWebWhenTheAppLeaves() {
        guard scenario == .clientOnTheWeb else { return }
        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: nil
        ) { [weak self] _ in
            Task { await self?.clientMovesThenCancels() }
        }
    }

    private func clientMovesThenCancels() {
        guard let index = bookings.firstIndex(where: {
            $0.id == UITestInboxFixtures.linkVisitBookingID && $0.status == .confirmed
        }) else { return }
        bookings[index] = UITestInboxFixtures.movedThenCancelledOnTheWeb(bookings[index], now: Date())
    }

    // MARK: - Reads

    func bookings(uid: String, since: Date) async throws -> [IncomingBooking] {
        bookings.filter { $0.startsAt >= since }
    }

    func rescheduleRequests(uid: String) async throws -> [RescheduleRequest] { requests }

    func waitlist(uid: String) async throws -> [WaitlistRequest] { waitlist }

    func booking(uid: String, id: String) async throws -> IncomingBooking? {
        bookings.first { $0.id == id }
    }

    func mailboxItems(uid: String) async throws -> [MailboxItem] {
        if !sealed, !scenario.isLinkVisitOnly {
            sealed = true
            let plaintext = UITestInboxFixtures.intakePlaintext(now: now)
            let itemID = UITestInboxFixtures.intakeItemID
            if let published = try? await publicKey(), let raw = Data(base64URL: published.pub),
               let key = try? Curve25519.KeyAgreement.PublicKey(rawRepresentation: raw),
               let envelope = try? EnvelopeOpener.seal(plaintext, to: key, kind: .intake, itemId: itemID) {
                items.append(MailboxItem(
                    id: itemID, kind: .intake, bookingId: UITestInboxFixtures.helenaBookingID, keyId: envelope.keyId,
                    sizeBytes: plaintext.count, createdAt: now.addingTimeInterval(-600), envelope: envelope
                ))
            }
        }
        return items
    }

    func mailboxItem(id: String) async throws -> MailboxItem {
        guard let item = items.first(where: { $0.id == id }) else { throw BookingRepositoryError.rejected }
        return item
    }

    // MARK: - Writes

    func respondBookingRequest(id: String, approve: Bool) async throws -> BookingRequestOutcome {
        guard let index = bookings.firstIndex(where: { $0.id == id }) else { throw BookingRepositoryError.rejected }
        if approve, scenario == .paywall { return .needsSubscription }
        bookings[index].status = approve ? .confirmed : .declined
        bookings[index].pendingReason = nil
        bookings[index].updatedAt = Date()
        return approve ? .confirmed : .declined
    }

    func respondRescheduleRequest(id: String, accept: Bool) async throws -> RescheduleOutcome {
        guard let index = requests.firstIndex(where: { $0.id == id }) else { throw BookingRepositoryError.rejected }
        requests[index].status = accept ? .accepted : .declined
        if accept, let booking = bookings.firstIndex(where: { $0.id == requests[index].bookingId }) {
            bookings[booking].startsAt = requests[index].requestedStart
            bookings[booking].endsAt = requests[index].requestedEnd
            bookings[booking].rescheduleCount += 1
            bookings[booking].updatedAt = Date()
        }
        return accept ? .accepted : .declined
    }

    func offerWaitlistSlot(_ offer: WaitlistOffer) async throws -> WaitlistOfferOutcome {
        guard let index = waitlist.firstIndex(where: { $0.id == offer.waitlistId }) else {
            throw BookingRepositoryError.rejected
        }
        waitlist[index].status = .offered
        waitlist[index].offeredAt = Date()
        return .offered(holdKey: "offer-\(offer.waitlistId)", expiresAt: Date().addingTimeInterval(3 * 3_600))
    }

    func suggestBookingTime(bookingId: String, startsAt: Date) async throws -> BookingSuggestionOutcome {
        guard let index = bookings.firstIndex(where: { $0.id == bookingId }) else {
            throw BookingRepositoryError.rejected
        }
        bookings[index].status = .declined
        return .suggested(holdKey: "suggest-\(bookingId)", expiresAt: Date().addingTimeInterval(3 * 3_600))
    }

    /// A fixed 22-character token per booking, so a UI test can find the exact link in the message.
    func mintManageLink(bookingId: String) async throws -> ClientManageLink {
        guard let booking = bookings.first(where: { $0.id == bookingId }), booking.status.holdsTime else {
            throw BookingRepositoryError.rejected
        }
        let letters = bookingId.filter { $0.isLetter || $0.isNumber }
        let token = String(("UITest" + letters + String(repeating: "x", count: 22)).prefix(22))
        let url = BookingLink.defaultBaseURL.appending(path: "m").appending(path: token)
        return ClientManageLink(url: url, expiresAt: booking.endsAt.addingTimeInterval(7 * 86_400))
    }

    func registerManualBooking(_ registration: ManualBookingRegistration) async throws -> ClientManageLink {
        let letters = registration.appointmentId.filter { $0.isLetter || $0.isNumber }
        let token = String(("UITest" + letters + String(repeating: "x", count: 22)).prefix(22))
        let url = BookingLink.defaultBaseURL.appending(path: "m").appending(path: token)
        return ClientManageLink(url: url, expiresAt: registration.endsAt.addingTimeInterval(7 * 86_400))
    }

    func removeWaitlistEntry(id: String) async throws {
        waitlist.removeAll { $0.id == id }
    }

    func resetNoShowCount(phone: String) async throws {}

    func cancelBookingByOwner(id: String) async throws {
        try change(id) {
            $0.status = .cancelledByPro
            $0.cancelledBy = "professional"
            $0.cancelledAt = Date()
            $0.isLateCancellation = false
        }
    }

    func moveBookingByOwner(id: String, startsAt: Date) async throws {
        try change(id) {
            $0.endsAt = startsAt.addingTimeInterval($0.endsAt.timeIntervalSince($0.startsAt))
            $0.startsAt = startsAt
            $0.clientConfirmedAt = nil
            $0.lateByMinutes = nil
        }
    }

    func markNoShow(phone: String, markId: UUID, markedAt: Date, bookingId: String) async throws {
        // The server counts the mark either way and changes only a booking still confirmed.
        guard let index = bookings.firstIndex(where: { $0.id == bookingId && $0.status == .confirmed }) else { return }
        bookings[index].status = .noShow
        bookings[index].updatedAt = Date()
    }

    func forgiveNoShow(phone: String, markId: UUID) async throws {}

    /// Like the server: only a booking that still holds time changes (`BOOKING_NOT_ACTIVE` otherwise).
    private func change(_ id: String, _ update: (inout IncomingBooking) -> Void) throws {
        guard let index = bookings.firstIndex(where: { $0.id == id }), bookings[index].status.holdsTime else {
            throw BookingRepositoryError.rejected
        }
        update(&bookings[index])
        bookings[index].updatedAt = Date()
    }

    func deleteClientServerData(phone: String?, bookingIds: [String]) async throws {
        bookings.removeAll { booking in bookingIds.contains(booking.id) || booking.client.phone == phone }
    }

    func acknowledgeMailboxItem(id: String) async throws {
        acknowledged.append(id)
        items.removeAll { $0.id == id }
    }

    func registerDevice(fcmToken: String, locale: String?) async throws {
        devices.append(fcmToken)
    }

    func unregisterDevice(fcmToken: String) async throws {
        devices.removeAll { $0 == fcmToken }
    }
}
#endif
