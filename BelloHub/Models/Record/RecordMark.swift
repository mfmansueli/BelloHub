//
//  RecordMark.swift
//  BelloHub
//

import Foundation

/// What Home and Alerts need to know about a record without its clinical content: whose it is, the appointment it
/// belongs to, whether it is still a draft and the service name for the line. Built on the iPhone from the vault and
/// never stored or sent anywhere.
struct RecordMark: Identifiable, Equatable, Sendable {
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

    var isDraft: Bool { status == .draft }

    /// A finalized record with no booking: a walk-in, or an earlier visit written later.
    var isWalkInVisit: Bool { !isDraft && appointmentID == nil }

    /// When the visit happened, as far as the record says: its visit day, else the day it was written.
    var visitDate: Date { performedAt ?? createdAt }
}
