//
//  RemoteInboxRepository.swift
//  BelloHub
//

import Foundation

/// The inbox server for real: direct Firestore reads for the lists (API.md section 8) and one owner function per write
/// (sections 6.3, 6.5, 6.6). It builds nothing and decides nothing; it speaks the contract and turns `ServerError`
/// into `BookingRepositoryError` through `RemoteBookingRepository.map`, so the two servers fail in the same words.
struct RemoteInboxRepository: InboxRepository {
    private let client: any CallableClient
    private let firestore: any FirestoreClient

    /// Never more than this many documents per read; bookings are purged 7 days after the visit, so a window is short.
    static let pageLimit = 500

    init(client: any CallableClient, firestore: any FirestoreClient) {
        self.client = client
        self.firestore = firestore
    }

    // MARK: - Reads

    func bookings(uid: String, since: Date) async throws -> [IncomingBooking] {
        try await read {
            try await firestore.query(
                collection: "bookings", ownerField: "ownerUid", uid: uid,
                since: FirestoreSince(field: "startsAt", date: since), limit: Self.pageLimit
            )
        }
    }

    func rescheduleRequests(uid: String) async throws -> [RescheduleRequest] {
        try await read {
            try await firestore.query(
                collection: "rescheduleRequests", ownerField: "ownerUid", uid: uid, since: nil, limit: Self.pageLimit
            )
        }
    }

    func waitlist(uid: String) async throws -> [WaitlistRequest] {
        try await read {
            try await firestore.query(
                collection: "waitlist", ownerField: "ownerUid", uid: uid, since: nil, limit: Self.pageLimit
            )
        }
    }

    func mailboxItems(uid: String) async throws -> [MailboxItem] {
        try await read { try await firestore.list(path: "inbox/\(uid)/items", limit: Self.pageLimit) }
    }

    // MARK: - Writes

    func respondBookingRequest(id: String, approve: Bool) async throws -> BookingRequestOutcome {
        let answer: StatusAnswer<BookingRequestOutcome> = try await perform(
            "respondBookingRequest", DecisionRequest(bookingId: id, decision: approve ? "approve" : "decline")
        )
        return answer.status
    }

    func respondRescheduleRequest(id: String, accept: Bool) async throws -> RescheduleOutcome {
        let answer: StatusAnswer<RescheduleOutcome> = try await perform(
            "respondRescheduleRequest",
            RescheduleDecisionRequest(requestId: id, decision: accept ? "accept" : "decline")
        )
        return answer.status
    }

    func offerWaitlistSlot(_ offer: WaitlistOffer) async throws -> WaitlistOfferOutcome {
        let answer: OfferAnswer = try await perform(
            "offerWaitlistSlot",
            OfferRequest(
                waitlistId: offer.waitlistId, serviceId: offer.serviceId, startsAt: offer.startsAt,
                holdMinutes: offer.holdMinutes
            )
        )
        if answer.status == "offered", let holdKey = answer.holdKey, let expiresAt = answer.expiresAt {
            return .offered(holdKey: holdKey, expiresAt: expiresAt)
        }
        return .slotTaken
    }

    func suggestBookingTime(bookingId: String, startsAt: Date) async throws -> BookingSuggestionOutcome {
        let answer: SuggestAnswer = try await perform(
            "suggestBookingTime", SuggestRequest(bookingId: bookingId, startsAt: startsAt)
        )
        if answer.status == "suggested", let holdKey = answer.holdKey, let expiresAt = answer.expiresAt {
            return .suggested(holdKey: holdKey, expiresAt: expiresAt)
        }
        return .slotTaken
    }

    func removeWaitlistEntry(id: String) async throws {
        let _: Acknowledged = try await perform("removeWaitlistEntry", WaitlistIDRequest(waitlistId: id))
    }

    func resetNoShowCount(phone: String) async throws {
        let _: CountAnswer = try await perform("markNoShow", NoShowRequest(phone: phone, action: "reset"))
    }

    func mailboxItem(id: String) async throws -> MailboxItem {
        let answer: MailboxItemAnswer = try await perform("getMailboxItem", ItemIDRequest(itemId: id))
        return MailboxItem(
            id: answer.itemId, kind: MailboxKind(persisted: answer.kind), bookingId: answer.bookingId,
            keyId: answer.envelope.keyId, sizeBytes: answer.envelope.ct.utf8.count, createdAt: answer.createdAt,
            envelope: answer.envelope
        )
    }

    func acknowledgeMailboxItem(id: String) async throws {
        let _: Acknowledged = try await perform("acknowledgeMailboxItem", ItemIDRequest(itemId: id))
    }

    func deleteClientServerData(phone: String?, bookingIds: [String]) async throws {
        let request = DeleteClientRequest(phone: phone, bookingIds: bookingIds.isEmpty ? nil : bookingIds)
        let _: DeletedAnswer = try await perform("deleteClientServerData", request)
    }

    func reserveRegistrations(_ claims: [RegistrationClaim]) async throws -> RegistrationReservation {
        let request = ReserveRequest(clients: claims.map {
            ReserveClaim(clientId: $0.clientID.uuidString.lowercased(), phone: $0.phone)
        })
        let answer: ReserveAnswer = try await perform("reserveRegistrations", request)
        let allowed = answer.results.filter { $0.decision == "allowed" }.map(\.clientId)
        let refused = answer.results.filter { $0.decision != "allowed" }.map(\.clientId)
        return RegistrationReservation(allowed: Set(allowed), refused: Set(refused), count: answer.count)
    }

    func registerDevice(fcmToken: String, locale: String?) async throws {
        let _: Acknowledged = try await perform(
            "registerDevice", RegisterDeviceRequest(fcmToken: fcmToken, platform: "ios", locale: locale)
        )
    }

    func unregisterDevice(fcmToken: String) async throws {
        let _: Acknowledged = try await perform("unregisterDevice", UnregisterDeviceRequest(fcmToken: fcmToken))
    }

    // MARK: - Mapping

    private func read<Row: Decodable>(_ fetch: () async throws -> [Data]) async throws -> [Row] {
        let rows: [Data]
        do {
            rows = try await fetch()
        } catch let error as ServerError {
            throw RemoteBookingRepository.map(error)
        }
        // A document the app cannot read (an older shape) is skipped, never a reason to hide the rest.
        return rows.compactMap { try? CallableJSON.decoder.decode(Row.self, from: $0) }
    }

    private func perform<Request: Encodable, Response: Decodable>(
        _ function: String, _ request: Request
    ) async throws -> Response {
        do {
            return try await client.call(function, request)
        } catch let error as ServerError {
            throw RemoteBookingRepository.map(error)
        }
    }

    // MARK: - Wire shapes

    private struct DecisionRequest: Encodable {
        let bookingId: String
        let decision: String
    }

    private struct RescheduleDecisionRequest: Encodable {
        let requestId: String
        let decision: String
    }

    private struct StatusAnswer<Status: Decodable>: Decodable { let status: Status }

    private struct OfferRequest: Encodable {
        let waitlistId: String
        let serviceId: String
        let startsAt: Date
        let holdMinutes: Int?
    }

    private struct OfferAnswer: Decodable {
        let status: String
        let holdKey: String?
        let expiresAt: Date?
    }

    private struct WaitlistIDRequest: Encodable { let waitlistId: String }

    private struct SuggestRequest: Encodable {
        let bookingId: String
        let startsAt: Date
    }

    private struct SuggestAnswer: Decodable {
        let status: String
        let holdKey: String?
        let expiresAt: Date?
    }

    private struct NoShowRequest: Encodable {
        let phone: String
        let action: String
    }

    private struct CountAnswer: Decodable { let counted: Int }

    private struct ItemIDRequest: Encodable { let itemId: String }

    private struct MailboxItemAnswer: Decodable {
        let itemId: String
        let kind: String
        let bookingId: String
        let createdAt: Date
        let envelope: SealedEnvelope
    }

    private struct RegisterDeviceRequest: Encodable {
        let fcmToken: String
        let platform: String
        let locale: String?
    }

    private struct UnregisterDeviceRequest: Encodable { let fcmToken: String }

    private struct DeleteClientRequest: Encodable {
        let phone: String?
        let bookingIds: [String]?
    }

    private struct ReserveClaim: Encodable {
        let clientId: String
        let phone: String?
    }

    private struct ReserveRequest: Encodable { let clients: [ReserveClaim] }

    private struct ReserveResult: Decodable {
        let clientId: UUID
        let decision: String
    }

    private struct ReserveAnswer: Decodable {
        let results: [ReserveResult]
        let count: Int
    }

    /// The counts per collection; the app only needs to know the call went through.
    private struct DeletedAnswer: Decodable { let deleted: [String: Int] }

    private struct Acknowledged: Decodable { let ok: Bool }
}
