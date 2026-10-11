//
//  OfflineInboxRepository.swift
//  BelloHub
//

import Foundation

/// No server (previews, a build without one): every read is empty and every write says so honestly, so the inbox shows
/// what the phone knows and nothing pretends to have reached the server.
struct OfflineInboxRepository: InboxRepository {
    func bookings(uid: String, since: Date) async throws -> [IncomingBooking] { [] }
    func rescheduleRequests(uid: String) async throws -> [RescheduleRequest] { [] }
    func waitlist(uid: String) async throws -> [WaitlistRequest] { [] }
    func booking(uid: String, id: String) async throws -> IncomingBooking? { nil }
    func cancelBookingByOwner(id: String) async throws { throw BookingRepositoryError.notPublishedYet }
    func moveBookingByOwner(id: String, startsAt: Date) async throws { throw BookingRepositoryError.notPublishedYet }
    func markNoShow(phone: String, markId: UUID, markedAt: Date, bookingId: String) async throws {
        throw BookingRepositoryError.notPublishedYet
    }
    func forgiveNoShow(phone: String, markId: UUID) async throws { throw BookingRepositoryError.notPublishedYet }
    func respondBookingRequest(id: String, approve: Bool) async throws -> BookingRequestOutcome {
        throw BookingRepositoryError.notPublishedYet
    }
    func respondRescheduleRequest(id: String, accept: Bool) async throws -> RescheduleOutcome {
        throw BookingRepositoryError.notPublishedYet
    }
    func offerWaitlistSlot(_ offer: WaitlistOffer) async throws -> WaitlistOfferOutcome {
        throw BookingRepositoryError.notPublishedYet
    }
    func suggestBookingTime(bookingId: String, startsAt: Date) async throws -> BookingSuggestionOutcome {
        throw BookingRepositoryError.notPublishedYet
    }
    func mintManageLink(bookingId: String) async throws -> ClientManageLink {
        throw BookingRepositoryError.notPublishedYet
    }
    func removeWaitlistEntry(id: String) async throws { throw BookingRepositoryError.notPublishedYet }
    func resetNoShowCount(phone: String) async throws { throw BookingRepositoryError.notPublishedYet }
    func mailboxItems(uid: String) async throws -> [MailboxItem] { [] }
    func mailboxItem(id: String) async throws -> MailboxItem { throw BookingRepositoryError.notPublishedYet }
    func acknowledgeMailboxItem(id: String) async throws { throw BookingRepositoryError.notPublishedYet }
    func deleteClientServerData(phone: String?, bookingIds: [String]) async throws {
        throw BookingRepositoryError.notPublishedYet
    }
    func reserveRegistrations(_ claims: [RegistrationClaim]) async throws -> RegistrationReservation {
        throw BookingRepositoryError.notPublishedYet
    }
    func registerDevice(fcmToken: String, locale: String?) async throws { throw BookingRepositoryError.notPublishedYet }
    func unregisterDevice(fcmToken: String) async throws { throw BookingRepositoryError.notPublishedYet }
}
