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

    init(_ record: TreatmentRecord) {
        id = record.id
        clientID = record.clientID
        appointmentID = record.appointmentID
        serviceID = record.serviceID
        serviceName = record.serviceName
        status = record.status
        createdAt = record.createdAt
    }

    var isDraft: Bool { status == .draft }
}
