//
//  TreatmentFlowUITestSeeding.swift
//  BelloHub
//

#if DEBUG
import Foundation

/// What `-uiTreatmentFlow` adds to the vault for the treatment flow's UI tests: a signed photo consent for the seeded
/// client Ana Costa, so the photo screens show the "consent signed" state and the visibility choices. Run it with
/// `-uiSeed clientWithHealth -uiRoute treatmentFlow`. DEBUG only.
enum TreatmentFlowUITestSeeding {
    static let argument = "-uiTreatmentFlow"

    @MainActor
    static func seedIfRequested(
        _ dependencies: AppDependencies, arguments: [String] = ProcessInfo.processInfo.arguments
    ) async {
        guard arguments.contains(argument), let repository = dependencies.vault.repository else { return }
        let consent = ConsentRecord(
            id: UUID(), clientID: UITestSeeding.healthClientID, kind: .photos, isSigned: true,
            signedAt: Date().addingTimeInterval(-86_400), createdAt: Date().addingTimeInterval(-86_400)
        )
        try? await repository.save(consent)
    }
}
#endif
