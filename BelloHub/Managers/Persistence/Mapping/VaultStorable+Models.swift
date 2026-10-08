//
//  VaultStorable+Models.swift
//  BelloHub
//

import Foundation

// How each domain type is stored: its kind, the columns that stay in the clear for queries, and the properties that
// are sealed (docs/05-DATA-MODEL.md section 1). One extension per type; the types themselves stay free of storage.

extension Client: VaultStorable {
    static var kind: VaultKind { .client }
    static var sensitiveKeys: Set<String> {
        ["importantNote", "allergies", "sensitivities", "preferences", "recurringRequests", "stopReason"]
    }

    var index: VaultIndex {
        VaultIndex(dateA: createdAt, textKey: name, statusRaw: isArchived ? "archived" : "active")
    }
}

extension Appointment: VaultStorable {
    static var kind: VaultKind { .appointment }
    static var sensitiveKeys: Set<String> { ["privateNote"] }

    var index: VaultIndex {
        VaultIndex(ownerID: clientID, secondaryID: serviceID, dateA: startsAt, dateB: endsAt,
                   textKey: serviceName, statusRaw: status.rawValue)
    }
}

extension Service: VaultStorable {
    static var kind: VaultKind { .service }

    var index: VaultIndex {
        VaultIndex(textKey: name, statusRaw: isActive ? "active" : "inactive")
    }
}

extension TreatmentRecord: VaultStorable {
    static var kind: VaultKind { .treatmentRecord }
    static var sensitiveKeys: Set<String> {
        ["notes", "technique", "productsUsed", "resultDetail", "aftercare", "nextSessionSuggestion"]
    }

    var index: VaultIndex {
        VaultIndex(ownerID: clientID, secondaryID: appointmentID, dateA: createdAt, dateB: lockedAt,
                   textKey: serviceName, statusRaw: result.rawValue)
    }
}

extension RecordCorrection: VaultStorable {
    static var kind: VaultKind { .correction }
    static var sensitiveKeys: Set<String> { ["oldValue", "newValue", "reason"] }

    var index: VaultIndex {
        VaultIndex(ownerID: recordID, dateA: createdAt, textKey: fieldKey)
    }
}

extension Incident: VaultStorable {
    static var kind: VaultKind { .incident }
    static var sensitiveKeys: Set<String> { ["symptoms", "area", "actionTaken", "followUp"] }

    var index: VaultIndex {
        VaultIndex(ownerID: clientID, secondaryID: recordID, dateA: occurredAt, dateB: lockedAt,
                   statusRaw: severity.rawValue)
    }
}

extension Photo: VaultStorable {
    static var kind: VaultKind { .photo }

    var index: VaultIndex {
        VaultIndex(ownerID: clientID, secondaryID: recordID, dateA: takenAt, statusRaw: kind.rawValue)
    }
}

extension HealthForm: VaultStorable {
    static var kind: VaultKind { .healthForm }
    static var sensitiveKeys: Set<String> { ["answers", "signatureImage", "guardianName", "minorName"] }

    var index: VaultIndex {
        VaultIndex(ownerID: clientID, dateA: signedAt, textKey: importedFromItemID)
    }
}

extension Consent: VaultStorable {
    static var kind: VaultKind { .consent }
    static var sensitiveKeys: Set<String> { ["typedSignature", "signatureImage"] }

    var index: VaultIndex {
        VaultIndex(ownerID: clientID, dateA: signedAt, statusRaw: kind.rawValue)
    }
}

extension SessionPlan: VaultStorable {
    static var kind: VaultKind { .sessionPlan }

    var index: VaultIndex {
        VaultIndex(ownerID: clientID, dateA: startDate, textKey: name)
    }
}

extension RegistrationLedgerEntry: VaultStorable {
    static var kind: VaultKind { .registration }

    var index: VaultIndex {
        VaultIndex(dateA: registeredAt)
    }
}
