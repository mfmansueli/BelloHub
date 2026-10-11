//
//  RescheduleRequest.swift
//  BelloHub
//

import Foundation

/// A client's request to move a booked visit, outside her free-change window (2.11, `rescheduleRequests/{id}`). The
/// current time stays booked until she accepts. Set by the server; the app answers through `respondRescheduleRequest`.
struct RescheduleRequest: Identifiable, Hashable, Codable, Sendable {
    enum Status: String, PersistedEnum {
        case pending
        case accepted
        case declined
        case cancelled

        static let fallback = Status.pending
    }

    let id: String
    var bookingId: String
    var clientName: String
    var serviceName: String
    var currentStart: Date
    var currentEnd: Date
    var requestedStart: Date
    var requestedEnd: Date
    var note: String?
    var status: Status
    var createdAt: Date

    init(
        id: String, bookingId: String, clientName: String, serviceName: String, currentStart: Date, currentEnd: Date,
        requestedStart: Date, requestedEnd: Date, note: String? = nil, status: Status = .pending, createdAt: Date
    ) {
        self.id = id
        self.bookingId = bookingId
        self.clientName = clientName
        self.serviceName = serviceName
        self.currentStart = currentStart
        self.currentEnd = currentEnd
        self.requestedStart = requestedStart
        self.requestedEnd = requestedEnd
        self.note = note
        self.status = status
        self.createdAt = createdAt
    }

    var isPending: Bool { status == .pending }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        bookingId = try container.decode(String.self, forKey: .bookingId)
        clientName = try container.decodeIfPresent(String.self, forKey: .clientName) ?? ""
        serviceName = try container.decodeIfPresent(String.self, forKey: .serviceName) ?? ""
        currentStart = try container.decode(Date.self, forKey: .currentStart)
        currentEnd = try container.decode(Date.self, forKey: .currentEnd)
        requestedStart = try container.decode(Date.self, forKey: .requestedStart)
        requestedEnd = try container.decode(Date.self, forKey: .requestedEnd)
        note = try container.decodeIfPresent(String.self, forKey: .note)
        status = Status(persisted: try container.decodeIfPresent(String.self, forKey: .status) ?? "pending")
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? currentStart
    }
}
