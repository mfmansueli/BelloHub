//
//  Incident.swift
//  BelloHub
//

import Foundation

/// A reaction or incident, with a neutral note of what the client reported or the professional saw.
/// Locks like a record.
struct Incident: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    var clientID: UUID
    var recordID: UUID?
    var occurredAt: Date
    var severity: IncidentSeverity
    var lockedAt: Date
    var needsFollowUp: Bool

    // Encrypted at rest.
    var symptoms: String?
    var area: String?
    var actionTaken: String?
    var followUp: String?
}
