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
        case .respondBookingRequest(let bookingId, _): "booking:\(bookingId)"
        case .respondRescheduleRequest(let requestId, _): "reschedule:\(requestId)"
        case .acknowledgeMailboxItem(let itemId): "mailbox:\(itemId)"
        case .removeWaitlistEntry(let waitlistId): "waitlist:\(waitlistId)"
        case .resetNoShowCount(let phone): "contact:\(phone)"
        case .registerDevice, .unregisterDevice: "device"
        }
    }
}
