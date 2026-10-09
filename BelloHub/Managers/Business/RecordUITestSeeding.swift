//
//  RecordUITestSeeding.swift
//  BelloHub
//

#if DEBUG
import Foundation

/// What `-uiRecords` adds to the vault for the record screens' UI tests (4.7, 4.9, 4.10): for the seeded client Ana
/// Costa, one record locked two days ago with one correction already logged, one record still open from an hour ago,
/// and one incident. The ids are fixed so a test can address the locked record's "Change" button. Run it with
/// `-uiSeed clientWithHealth`. DEBUG only.
enum RecordUITestSeeding {
    static let argument = "-uiRecords"
    static let lockedRecordID = UUID(uuidString: "C0FFEE00-0000-4000-8000-00000000A001") ?? UUID()
    static let openRecordID = UUID(uuidString: "C0FFEE00-0000-4000-8000-00000000A002") ?? UUID()

    @MainActor
    static func seedIfRequested(
        _ dependencies: AppDependencies, arguments: [String] = ProcessInfo.processInfo.arguments
    ) async {
        guard arguments.contains(argument), let repository = dependencies.vault.repository else { return }
        let now = Date()
        let clientID = UITestSeeding.healthClientID
        let locked = TreatmentRecord(
            id: lockedRecordID, clientID: clientID, serviceName: "Deep cleansing facial",
            createdAt: now.addingTimeInterval(-2 * 86_400), result: .good, notes: "Skin a little sensitive.",
            technique: "Gentle extraction", productsUsed: ["Calming serum"], aftercare: "No sun for 48 hours"
        )
        let open = TreatmentRecord(
            id: openRecordID, clientID: clientID, serviceName: "Hydrating facial",
            createdAt: now.addingTimeInterval(-3_600), notes: "Skin hydrated, no redness."
        )
        let correction = RecordCorrection(
            id: UUID(), recordID: lockedRecordID, createdAt: now.addingTimeInterval(-86_400), fieldKey: "aftercare",
            oldValue: "No sun for 48 hours", newValue: "No sun for 72 hours", reason: "Wrote the wrong number of hours"
        )
        let incident = Incident(
            id: UUID(), clientID: clientID, recordID: lockedRecordID, occurredAt: now.addingTimeInterval(-86_400),
            severity: .mild, lockedAt: RecordLockPolicy.lockedAt(createdAt: now.addingTimeInterval(-86_400)),
            needsFollowUp: true, symptoms: "Redness", area: "Cheeks", actionTaken: "Advised the client", followUp: nil
        )
        try? await repository.save(locked)
        try? await repository.save(open)
        try? await repository.addCorrection(correction)
        try? await repository.save(incident)
    }
}
#endif
