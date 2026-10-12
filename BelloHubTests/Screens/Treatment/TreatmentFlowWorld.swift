//
//  TreatmentFlowWorld.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation

/// A client, a vault and a visit form opened on her, shared by the treatment flow suites.
@MainActor
struct TreatmentFlowWorld {
    let model: TreatmentFlowViewModel
    let repository: any ClientRecordRepository
    let voice: FakeVoiceCapture
    let client: Client

    static func make(
        request: ((UUID) -> TreatmentFlowRequest)? = nil,
        voice: FakeVoiceCapture = FakeVoiceCapture(),
        structuring: any RecordStructuring = UnavailableRecordStructuring(),
        photoProcessing: any PhotoProcessing = FakePhotoProcessing(),
        withPhotoConsent: Bool = false,
        seed: (any ClientRecordRepository, Client) async throws -> Void = { _, _ in }
    ) async throws -> TreatmentFlowWorld {
        let world = try await ClientsWorld.make()
        let client = makeClient(name: "Ana Costa")
        _ = try await world.repository.save(client)
        if withPhotoConsent {
            try await world.repository.save(ConsentRecord(
                id: UUID(), clientID: client.id, kind: .photos, isSigned: true, signedAt: TestClock.days(-3),
                createdAt: TestClock.days(-3)
            ))
        }
        try await seed(world.repository, client)
        let recordID = UUID()
        let model = TreatmentFlowViewModel(
            request: request?(client.id) ?? TreatmentFlowRequest(clientID: client.id), repository: world.repository,
            profile: world.profile, voice: voice, structuring: structuring, photoProcessing: photoProcessing,
            names: .init(serviceFallback: "Treatment", notes: "Observations", recommendation: "Recommendation"),
            autosaveDelay: .zero, now: { TestClock.now }, makeID: { recordID }
        )
        await model.load()
        return TreatmentFlowWorld(model: model, repository: world.repository, voice: voice, client: client)
    }
}
