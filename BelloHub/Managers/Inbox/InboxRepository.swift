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
    /// One of her bookings by id, wherever its time is; nil when the server no longer has it (purged, deleted). The
    /// sync asks for a visit whose booking left the list it reads, so no visit stays stale out of sight.
    func booking(uid: String, id: String) async throws -> IncomingBooking?

    /// She cancelled a link visit in the app (`cancelBookingByOwner`): the booking becomes `cancelledByPro` and the
    /// client is told. `BOOKING_NOT_ACTIVE` (`rejected`) when it no longer holds time on the server.
    func cancelBookingByOwner(id: String) async throws
    /// She moved a link visit in the app (`moveBookingByOwner`); the server keeps the booking's length.
    func moveBookingByOwner(id: String, startsAt: Date) async throws
    /// `markNoShow` `mark` with the booking: her count for that phone, and the booking's status becomes `noShow`.
    func markNoShow(phone: String, markId: UUID, markedAt: Date, bookingId: String) async throws
    /// `markNoShow` `forgive`: that mark no longer counts.
    func forgiveNoShow(phone: String, markId: UUID) async throws

    func respondBookingRequest(id: String, approve: Bool) async throws -> BookingRequestOutcome
    func respondRescheduleRequest(id: String, accept: Bool) async throws -> RescheduleOutcome
    func offerWaitlistSlot(_ offer: WaitlistOffer) async throws -> WaitlistOfferOutcome
    /// "Suggest another time": declines the request and holds `startsAt` for the client (`suggestBookingTime`).
    func suggestBookingTime(bookingId: String, startsAt: Date) async throws -> BookingSuggestionOutcome
    /// The client's own link to change or cancel one booking (`mintManageLink`), for a message she sends herself. The
    /// server returns the same link for 30 minutes and refuses a booking that no longer holds time.
    func mintManageLink(bookingId: String) async throws -> ClientManageLink
    func removeWaitlistEntry(id: String) async throws
    /// `markNoShow` with `reset`: her count starts from zero and online booking opens again for her (2.10).
    func resetNoShowCount(phone: String) async throws

    /// The sealed items waiting for her, metadata and small envelopes.
    func mailboxItems(uid: String) async throws -> [MailboxItem]
    /// The same item with its envelope, for items stored in Storage.
    func mailboxItem(id: String) async throws -> MailboxItem
    /// Deletes the item on the server; an unknown id is also fine (idempotent).
    func acknowledgeMailboxItem(id: String) async throws

    /// `deleteClientServerData` (D30): the server forgets a client she deleted on the phone: her bookings, sealed
    /// items, requests, waitlist rows, portal and contact row. At most 200 booking ids per call; idempotent.
    func deleteClientServerData(phone: String?, bookingIds: [String]) async throws

    func registerDevice(fcmToken: String, locale: String?) async throws
    func unregisterDevice(fcmToken: String) async throws
}
