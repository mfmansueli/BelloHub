//
//  UITestInboxRepository.swift
//  BelloHub
//

#if DEBUG
import CryptoKit
import Foundation

/// An in-memory inbox server for UI tests (`-uiInbox fixtures`): the data of `UITestInboxFixtures` plus one sealed
/// health form for Helena, sealed at first read to the test key (`InMemoryKeyStore` seed), so the whole
/// open-and-import path runs on the simulator. Answers change the data like the server would. DEBUG only.
///
/// `-uiInbox paywall` makes the approval answer `needsSubscription` (D42). `-uiInbox unverified` makes Ana's request
/// one made without the e-mail code ("Confirm on WhatsApp", verify-fallback).
///
/// An actor, not a @MainActor class: `InboxRepository` is Sendable and the services call it from nonisolated tasks.
actor UITestInboxRepository: InboxRepository {
    enum Scenario: String {
        case fixtures
        case paywall
        case unverified
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
        bookings = UITestInboxFixtures.bookings(now: now, unverified: scenario == .unverified)
        requests = UITestInboxFixtures.requests(now: now)
        waitlist = UITestInboxFixtures.waitlist(now: now)
    }

    // MARK: - Reads

    func bookings(uid: String, since: Date) async throws -> [IncomingBooking] {
        bookings.filter { $0.startsAt >= since }
    }

    func rescheduleRequests(uid: String) async throws -> [RescheduleRequest] { requests }

    func waitlist(uid: String) async throws -> [WaitlistRequest] { waitlist }

    func mailboxItems(uid: String) async throws -> [MailboxItem] {
        if !sealed {
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

    func removeWaitlistEntry(id: String) async throws {
        waitlist.removeAll { $0.id == id }
    }

    func resetNoShowCount(phone: String) async throws {}

    /// Everything is allowed: UI tests drive the free limit through the vault's own count (`-uiPlan`).
    func reserveRegistrations(_ claims: [RegistrationClaim]) async throws -> RegistrationReservation {
        RegistrationReservation(allowed: Set(claims.map(\.clientID)), refused: [], count: claims.count)
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
