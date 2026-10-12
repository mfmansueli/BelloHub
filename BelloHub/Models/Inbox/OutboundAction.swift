//
//  OutboundAction.swift
//  BelloHub
//

import Foundation

/// A write to the server that was decided on the phone and must reach it even if the network is away now
/// (docs/04-ARCHITECTURE.md section 3, "offline first"). The `id` is the idempotent key: the same action is never
/// sent twice as two different things, and replaying it after a crash is safe (every target function tolerates a
/// repeat: a second acknowledge is `ok`, a second answer to a request is refused as already answered and dropped).
struct OutboundAction: Identifiable, Hashable, Codable, Sendable {
    enum Kind: Hashable, Codable, Sendable {
        case respondBookingRequest(bookingId: String, approve: Bool)
        case respondRescheduleRequest(requestId: String, accept: Bool)
        case acknowledgeMailboxItem(itemId: String)
        case removeWaitlistEntry(waitlistId: String)
        case resetNoShowCount(phone: String)
        case registerDevice(fcmToken: String, locale: String?)
        case unregisterDevice(fcmToken: String)
        /// She deleted a client on the phone: the server forgets her too (D30). At most 200 booking ids per action.
        case deleteClientServerData(phone: String?, bookingIds: [String])
        /// Clients registered while the server was away (D42). Since D59 nothing enqueues it and the server no longer
        /// counts for the app; it stays only so a queue saved by an older version still reads, and is dropped unsent.
        case reserveRegistrations(claims: [RegistrationClaim])
        /// She cancelled a link visit in the app (`cancelBookingByOwner`).
        case cancelBookingByOwner(bookingId: String)
        /// She moved a link visit in the app (`moveBookingByOwner`).
        case moveBookingByOwner(bookingId: String, startsAt: Date)
        /// She marked a link visit as a no-show (`markNoShow` `mark` with the booking: its status becomes `noShow`).
        case markNoShow(bookingId: String, phone: String, markId: UUID, markedAt: Date)
        /// She forgave that no-show (`markNoShow` `forgive`): it no longer counts against the client.
        case forgiveNoShow(bookingId: String, phone: String, markId: UUID)

        /// The link booking whose state this action changes on the server. Until the server took it, a sync must not
        /// put the server's older state back over her change (`BookingImporter`).
        var changedBookingID: String? {
            switch self {
            case .cancelBookingByOwner(let id), .moveBookingByOwner(let id, _), .markNoShow(let id, _, _, _),
                 .forgiveNoShow(let id, _, _):
                id
            default:
                nil
            }
        }
    }

    let id: UUID
    let kind: Kind
    let createdAt: Date
    var attempts: Int

    init(id: UUID = UUID(), kind: Kind, createdAt: Date, attempts: Int = 0) {
        self.id = id
        self.kind = kind
        self.createdAt = createdAt
        self.attempts = attempts
    }

    /// Actions on the same thing are sent in order; unrelated ones may be reordered after a failure.
    var aggregate: String {
        switch kind {
        case .respondBookingRequest(let bookingId, _), .cancelBookingByOwner(let bookingId),
             .moveBookingByOwner(let bookingId, _), .markNoShow(let bookingId, _, _, _),
             .forgiveNoShow(let bookingId, _, _):
            "booking:\(bookingId)"
        case .respondRescheduleRequest(let requestId, _): "reschedule:\(requestId)"
        case .acknowledgeMailboxItem(let itemId): "mailbox:\(itemId)"
        case .removeWaitlistEntry(let waitlistId): "waitlist:\(waitlistId)"
        case .resetNoShowCount(let phone): "contact:\(phone)"
        case .registerDevice, .unregisterDevice: "device"
        case .deleteClientServerData(let phone, let bookingIds): "contact:\(phone ?? bookingIds.first ?? "")"
        case .reserveRegistrations: "registrations"
        }
    }
}
