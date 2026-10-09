//
//  InboxRepository.swift
//  BelloHub
//

import Foundation

/// The server side of what arrives through her link: bookings, reschedule requests, the waitlist, the sealed mailbox
/// and her devices for push (firebase/functions/API.md sections 6.3, 6.5, 6.6 and 8). Reads are the owner's direct
/// Firestore reads; writes are callable functions. Clinical data never travels through it: the mailbox items are
/// opaque envelopes until `MailboxService` opens them on the phone.
///
/// `RemoteInboxRepository` talks to the server; `OfflineInboxRepository` is the stand-in for builds without one;
/// `UITestInboxRepository` (DEBUG) is an in-memory server for UI tests. Every method throws `BookingRepositoryError`.
protocol InboxRepository: Sendable {
    /// Her bookings whose visit starts at or after `since`.
    func bookings(uid: String, since: Date) async throws -> [IncomingBooking]
    func rescheduleRequests(uid: String) async throws -> [RescheduleRequest]
    func waitlist(uid: String) async throws -> [WaitlistRequest]

    func respondBookingRequest(id: String, approve: Bool) async throws -> BookingRequestOutcome
    func respondRescheduleRequest(id: String, accept: Bool) async throws -> RescheduleOutcome
    func offerWaitlistSlot(_ offer: WaitlistOffer) async throws -> WaitlistOfferOutcome
    func removeWaitlistEntry(id: String) async throws
    /// `markNoShow` with `reset`: her count starts from zero and online booking opens again for her (2.10).
    func resetNoShowCount(phone: String) async throws

    /// The sealed items waiting for her, metadata and small envelopes.
    func mailboxItems(uid: String) async throws -> [MailboxItem]
    /// The same item with its envelope, for items stored in Storage.
    func mailboxItem(id: String) async throws -> MailboxItem
    /// Deletes the item on the server; an unknown id is also fine (idempotent).
    func acknowledgeMailboxItem(id: String) async throws

    func registerDevice(fcmToken: String, locale: String?) async throws
    func unregisterDevice(fcmToken: String) async throws
}
