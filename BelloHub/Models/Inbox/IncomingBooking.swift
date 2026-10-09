//
//  IncomingBooking.swift
//  BelloHub
//

import Foundation

/// A booking made through her link, as the server holds it (`bookings/{id}`, API.md section 8). Operational data
/// only: who, what, when and the policy snapshot (D47). **Every field is set by the server**; the app answers a request
/// through `respondBookingRequest` and never writes a booking (rules: `allow write: if false`).
struct IncomingBooking: Identifiable, Hashable, Codable, Sendable {
    struct AddOn: Hashable, Codable, Sendable {
        let id: String
        let name: String
        let minutes: Int
    }

    struct ClientInfo: Hashable, Codable, Sendable {
        let name: String
        let phone: String
        let email: String?
        let locale: String?
    }

    struct NoShowSnapshot: Hashable, Codable, Sendable {
        let isOn: Bool
        let limit: Int
        let lateCancelCounts: Bool
    }

    let id: String
    var status: IncomingBookingStatus
    var pendingReason: PendingReason?
    var serviceId: String
    var serviceName: String
    var durationMinutes: Int
    var addOns: [AddOn]
    var guestCount: Int
    var startsAt: Date
    var endsAt: Date
    var timeZoneID: String
    var client: ClientInfo
    var note: String?
    /// `bookingLink`, `rebook` or `waitlist`; the agenda shows them all as link bookings.
    var origin: String?
    var policy: CancellationPolicy?
    var noShowPolicy: NoShowSnapshot?
    var clientConfirmedAt: Date?
    var lateByMinutes: Int?
    var rescheduleCount: Int
    var cancelledAt: Date?
    var cancelledBy: String?
    var isLateCancellation: Bool?
    var cancelReason: String?
    var intakeSubmittedAt: Date?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: String,
        status: IncomingBookingStatus,
        pendingReason: PendingReason? = nil,
        serviceId: String,
        serviceName: String,
        durationMinutes: Int,
        addOns: [AddOn] = [],
        guestCount: Int = 0,
        startsAt: Date,
        endsAt: Date,
        timeZoneID: String,
        client: ClientInfo,
        note: String? = nil,
        origin: String? = "bookingLink",
        policy: CancellationPolicy? = nil,
        noShowPolicy: NoShowSnapshot? = nil,
        clientConfirmedAt: Date? = nil,
        lateByMinutes: Int? = nil,
        rescheduleCount: Int = 0,
        cancelledAt: Date? = nil,
        cancelledBy: String? = nil,
        isLateCancellation: Bool? = nil,
        cancelReason: String? = nil,
        intakeSubmittedAt: Date? = nil,
        createdAt: Date,
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.status = status
        self.pendingReason = pendingReason
        self.serviceId = serviceId
        self.serviceName = serviceName
        self.durationMinutes = durationMinutes
        self.addOns = addOns
        self.guestCount = guestCount
        self.startsAt = startsAt
        self.endsAt = endsAt
        self.timeZoneID = timeZoneID
        self.client = client
        self.note = note
        self.origin = origin
        self.policy = policy
        self.noShowPolicy = noShowPolicy
        self.clientConfirmedAt = clientConfirmedAt
        self.lateByMinutes = lateByMinutes
        self.rescheduleCount = rescheduleCount
        self.cancelledAt = cancelledAt
        self.cancelledBy = cancelledBy
        self.isLateCancellation = isLateCancellation
        self.cancelReason = cancelReason
        self.intakeSubmittedAt = intakeSubmittedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt ?? createdAt
    }

    /// Service plus add-ons plus guests, as the server computed it.
    var totalMinutes: Int { max(Int(endsAt.timeIntervalSince(startsAt) / 60), 0) }

    /// A request (2.10) that still waits for her answer.
    var isPendingRequest: Bool { status.isRequest }

    /// The service id as the vault knows it (the server keeps ids lower-case).
    var serviceUUID: UUID? { UUID(uuidString: serviceId) }

    /// Optional server fields decode as nil when absent; the required ones must be there.
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        status = IncomingBookingStatus(persisted: try container.decode(String.self, forKey: .status))
        pendingReason = try container.decodeIfPresent(String.self, forKey: .pendingReason).map(PendingReason.init(persisted:))
        serviceId = try container.decode(String.self, forKey: .serviceId)
        serviceName = try container.decode(String.self, forKey: .serviceName)
        durationMinutes = try container.decodeIfPresent(Int.self, forKey: .durationMinutes) ?? 0
        addOns = try container.decodeIfPresent([AddOn].self, forKey: .addOns) ?? []
        guestCount = try container.decodeIfPresent(Int.self, forKey: .guestCount) ?? 0
        startsAt = try container.decode(Date.self, forKey: .startsAt)
        endsAt = try container.decode(Date.self, forKey: .endsAt)
        timeZoneID = try container.decodeIfPresent(String.self, forKey: .timeZoneID) ?? "UTC"
        client = try container.decode(ClientInfo.self, forKey: .client)
        note = try container.decodeIfPresent(String.self, forKey: .note)
        origin = try container.decodeIfPresent(String.self, forKey: .origin)
        policy = try? container.decodeIfPresent(CancellationPolicy.self, forKey: .policy)
        noShowPolicy = try? container.decodeIfPresent(NoShowSnapshot.self, forKey: .noShowPolicy)
        clientConfirmedAt = try container.decodeIfPresent(Date.self, forKey: .clientConfirmedAt)
        lateByMinutes = try container.decodeIfPresent(Int.self, forKey: .lateByMinutes)
        rescheduleCount = try container.decodeIfPresent(Int.self, forKey: .rescheduleCount) ?? 0
        cancelledAt = try container.decodeIfPresent(Date.self, forKey: .cancelledAt)
        cancelledBy = try container.decodeIfPresent(String.self, forKey: .cancelledBy)
        isLateCancellation = try container.decodeIfPresent(Bool.self, forKey: .isLateCancellation)
        cancelReason = try container.decodeIfPresent(String.self, forKey: .cancelReason)
        intakeSubmittedAt = try container.decodeIfPresent(Date.self, forKey: .intakeSubmittedAt)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? startsAt
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? createdAt
    }
}
