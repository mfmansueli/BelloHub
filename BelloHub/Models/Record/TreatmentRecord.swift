//
//  TreatmentRecord.swift
//  BelloHub
//

import Foundation

/// What was done in a visit. **Locks 24 hours after creation**: after `lockedAt` it changes only through a
/// `RecordCorrection` (`RecordLockPolicy`). The text fields are encrypted at rest.
struct TreatmentRecord: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    var clientID: UUID
    var appointmentID: UUID?
    var serviceID: UUID?
    var serviceName: String
    var createdAt: Date
    var lockedAt: Date
    var source: RecordSource
    var result: RecordResult
    /// True when the on-device AI proposed the draft. It was always reviewed before saving.
    var aiAssisted: Bool

    // Encrypted at rest.
    var notes: String?
    var technique: String?
    var productsUsed: [String]
    var resultDetail: String?
    var aftercare: String?
    var nextSessionSuggestion: String?

    init(
        id: UUID = UUID(),
        clientID: UUID,
        appointmentID: UUID? = nil,
        serviceID: UUID? = nil,
        serviceName: String,
        createdAt: Date,
        source: RecordSource = .manual,
        result: RecordResult = .neutral,
        aiAssisted: Bool = false,
        notes: String? = nil,
        technique: String? = nil,
        productsUsed: [String] = [],
        resultDetail: String? = nil,
        aftercare: String? = nil,
        nextSessionSuggestion: String? = nil
    ) {
        self.id = id
        self.clientID = clientID
        self.appointmentID = appointmentID
        self.serviceID = serviceID
        self.serviceName = serviceName
        self.createdAt = createdAt
        self.lockedAt = RecordLockPolicy.lockedAt(createdAt: createdAt)
        self.source = source
        self.result = result
        self.aiAssisted = aiAssisted
        self.notes = notes
        self.technique = technique
        self.productsUsed = productsUsed
        self.resultDetail = resultDetail
        self.aftercare = aftercare
        self.nextSessionSuggestion = nextSessionSuggestion
    }
}
