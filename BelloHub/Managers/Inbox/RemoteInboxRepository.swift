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
    /// 10 pages of 500 bookings: far beyond a real agenda, and a bound if the server ever answered in a loop.
    static let maxPages = 10

    init(client: any CallableClient, firestore: any FirestoreClient) {
        self.client = client
        self.firestore = firestore
    }

    // MARK: - Reads

    /// Every booking from `since` on, a page at a time: a busy agenda can hold more than one page, and a booking cut
    /// off the end of the first page would never reach the phone. The next page starts at the last start read
    /// (inclusive, so bookings at the same minute are not skipped) and repeats are dropped by id.
    func bookings(uid: String, since: Date) async throws -> [IncomingBooking] {
        var all: [IncomingBooking] = []
        var seen: Set<String> = []
        var cursor = since
        for _ in 0..<Self.maxPages {
            let rows = try await fetch {
                try await firestore.query(
                    collection: "bookings", ownerField: "ownerUid", uid: uid,
                    since: FirestoreSince(field: "startsAt", date: cursor), limit: Self.pageLimit
                )
            }
            let page: [IncomingBooking] = Self.decode(rows)
            for booking in page where seen.insert(booking.id).inserted { all.append(booking) }
            // A short page is the last one (counted before decoding: a skipped document still filled the page). A full
            // page whose last start is the cursor could only repeat itself.
            guard rows.count >= Self.pageLimit, let last = page.map(\.startsAt).max(), last > cursor else { break }
            cursor = last
        }
        return all
    }

    func booking(uid: String, id: String) async throws -> IncomingBooking? {
        let row: Data?
        do {
            row = try await firestore.document(path: "bookings/\(id)")
        } catch let error as ServerError {
            throw RemoteBookingRepository.map(error)
        }
        guard let row, let booking = try? CallableJSON.decoder.decode(IncomingBooking.self, from: row) else {
            return nil
        }
        return booking
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

    func mintManageLink(bookingId: String) async throws -> ClientManageLink {
        let answer: ManageLinkAnswer = try await perform("mintManageLink", BookingIDRequest(bookingId: bookingId))
        guard let url = URL(string: answer.url), url.scheme == "https" else { throw BookingRepositoryError.rejected }
        return ClientManageLink(url: url, expiresAt: answer.expiresAt)
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

    private func read<Row: Decodable>(_ rows: () async throws -> [Data]) async throws -> [Row] {
        Self.decode(try await fetch(rows))
    }

    private func fetch(_ rows: () async throws -> [Data]) async throws -> [Data] {
        do {
            return try await rows()
        } catch let error as ServerError {
            throw RemoteBookingRepository.map(error)
        }
    }

    /// A document the app cannot read (an older or newer shape) is skipped, never a reason to hide the rest.
    private static func decode<Row: Decodable>(_ rows: [Data]) -> [Row] {
        rows.compactMap { try? CallableJSON.decoder.decode(Row.self, from: $0) }
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

    private struct BookingIDRequest: Encodable { let bookingId: String }

    private struct ManageLinkAnswer: Decodable {
        let url: String
        let expiresAt: Date
    }

    /// Absent optionals are left out (never `null`): the server's schema is strict.
    private struct NoShowRequest: Encodable {
        let phone: String
        let action: String
        var markId: String?
        var markedAt: Date?
        var bookingId: String?
    }

    private struct MoveRequest: Encodable {
        let bookingId: String
        let startsAt: Date
    }

    private struct CancelAnswer: Decodable { let status: String }

    private struct MoveAnswer: Decodable {
        let startsAt: Date
        let endsAt: Date
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

// MARK: - Her changes to link visits

/// `cancelBookingByOwner`, `moveBookingByOwner` and `markNoShow` (API.md 6.3), sent by the `OutboundQueue` when she
/// changes a link visit in the app, so the booking, the client's manage page and the waitlist follow.
extension RemoteInboxRepository {
    func cancelBookingByOwner(id: String) async throws {
        let _: CancelAnswer = try await perform("cancelBookingByOwner", BookingIDRequest(bookingId: id))
    }

    func moveBookingByOwner(id: String, startsAt: Date) async throws {
        let _: MoveAnswer = try await perform("moveBookingByOwner", MoveRequest(bookingId: id, startsAt: startsAt))
    }

    func markNoShow(phone: String, markId: UUID, markedAt: Date, bookingId: String) async throws {
        let request = NoShowRequest(
            phone: phone, action: "mark", markId: markId.uuidString.lowercased(), markedAt: markedAt,
            bookingId: bookingId
        )
        let _: CountAnswer = try await perform("markNoShow", request)
    }

    func forgiveNoShow(phone: String, markId: UUID) async throws {
        let request = NoShowRequest(phone: phone, action: "forgive", markId: markId.uuidString.lowercased())
        let _: CountAnswer = try await perform("markNoShow", request)
    }
}
