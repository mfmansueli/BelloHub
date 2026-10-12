//
//  RecordMark.swift
//  BelloHub
//

import Foundation

/// What Home and Alerts need to know about a record without its clinical content: whose it is, the appointment it
/// belongs to, whether it is still a draft and the service name for the line. Built on the iPhone from the vault and
/// never stored or sent anywhere. It decodes from a record's clear JSON only (every key here is outside
/// `TreatmentRecord`'s sensitive keys), so reading marks never opens a sealed part.
struct RecordMark: Identifiable, Equatable, Decodable, Sendable {
    let id: UUID
    let clientID: UUID
    let appointmentID: UUID?
    let serviceID: UUID?
    let serviceName: String
    let status: RecordStatus
    let createdAt: Date
    /// The day the visit happened when she noted one; corrections to it are not applied here (only the record's own
    /// screens read corrections).
    let performedAt: Date?

    init(_ record: TreatmentRecord) {
        id = record.id
        clientID = record.clientID
        appointmentID = record.appointmentID
        serviceID = record.serviceID
        serviceName = record.serviceName
        status = record.status
        createdAt = record.createdAt
        performedAt = record.performedAt
    }

    private enum CodingKeys: String, CodingKey {
        case id, clientID, appointmentID, serviceID, serviceName, status, createdAt, performedAt
    }

    /// The same defaults as `TreatmentRecord`: no status means a record from before drafts, final when written.
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        clientID = try container.decode(UUID.self, forKey: .clientID)
        appointmentID = try container.decodeIfPresent(UUID.self, forKey: .appointmentID)
        serviceID = try container.decodeIfPresent(UUID.self, forKey: .serviceID)
        serviceName = try container.decodeIfPresent(String.self, forKey: .serviceName) ?? ""
        status = try container.decodeIfPresent(RecordStatus.self, forKey: .status) ?? .finalized
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        performedAt = try container.decodeIfPresent(Date.self, forKey: .performedAt)
    }

    var isDraft: Bool { status == .draft }

    /// A finalized record with no booking: a walk-in, or an earlier visit written later.
    var isWalkInVisit: Bool { !isDraft && appointmentID == nil }

    /// When the visit happened, as far as the record says: its visit day, else the day it was written.
    var visitDate: Date { performedAt ?? createdAt }
}
