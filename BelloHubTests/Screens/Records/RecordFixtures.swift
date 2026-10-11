//
//  RecordFixtures.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation

func makeRecord(
    id: UUID = UUID(), clientID: UUID = UUID(), appointmentID: UUID? = nil, serviceName: String = "Glow Facial",
    createdAt: Date = TestClock.days(-3), source: RecordSource = .manual, result: RecordResult = .good,
    notes: String? = "Skin a little sensitive.", technique: String? = "Gentle peel",
    aftercare: String? = nil, products: [String] = ["Calming serum"]
) -> TreatmentRecord {
    TreatmentRecord(
        id: id, clientID: clientID, appointmentID: appointmentID, serviceName: serviceName, createdAt: createdAt,
        source: source, result: result, notes: notes, technique: technique, productsUsed: products,
        aftercare: aftercare
    )
}

func makeCorrection(
    id: UUID = UUID(), recordID: UUID, createdAt: Date = TestClock.now, field: RecordCorrectableField = .aftercare,
    old: String? = nil, new: String? = "Gentle cleansing for 48 hours.", reason: String? = "Forgot to write it"
) -> RecordCorrection {
    RecordCorrection(
        id: id, recordID: recordID, createdAt: createdAt, fieldKey: field.rawValue, oldValue: old, newValue: new,
        reason: reason
    )
}

func makePhoto(
    id: UUID = UUID(), clientID: UUID = UUID(), recordID: UUID? = nil, takenAt: Date = TestClock.days(-3),
    kind: PhotoKind = .before, visibility: PhotoVisibility = .professionalOnly
) -> Photo {
    Photo(id: id, clientID: clientID, recordID: recordID, takenAt: takenAt, kind: kind, visibility: visibility)
}

func makeIncident(
    id: UUID = UUID(), clientID: UUID = UUID(), occurredAt: Date = TestClock.days(-1),
    severity: IncidentSeverity = .mild
) -> Incident {
    Incident(
        id: id, clientID: clientID, recordID: nil, occurredAt: occurredAt, severity: severity,
        lockedAt: RecordLockPolicy.lockedAt(createdAt: occurredAt), needsFollowUp: true, symptoms: "Redness",
        area: "Cheeks", actionTaken: "Advised client", followUp: nil
    )
}

func makeConsent(
    clientID: UUID = UUID(), kind: ConsentKind = .treatment, signedAt: Date = TestClock.days(-30),
    isSigned: Bool = true, label: String? = nil
) -> ConsentRecord {
    ConsentRecord(
        id: UUID(), clientID: clientID, kind: kind, isSigned: isSigned, signedAt: isSigned ? signedAt : nil,
        createdAt: signedAt, label: label, note: "Paper form in the drawer",
        document: ConsentDocument(
            kind: .photo, fileName: nil, contentType: "public.jpeg", data: Data([1, 2, 3]), thumbnail: Data([1])
        )
    )
}
