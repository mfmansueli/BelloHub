//
//  TreatmentFlowPhotoTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@MainActor
@Suite("TreatmentFlowViewModel photos", .serialized)
struct TreatmentFlowPhotoTests {
    // MARK: - Photos

    @Test("A photo is saved at once, private when no photo consent is signed")
    func photoWithoutConsent() async throws {
        let world = try await TreatmentFlowWorld.make()
        world.model.set("x", for: TreatmentFormField.notesKey)
        await world.model.finalize()
        let added = await world.model.addPhoto(Data([1, 2, 3]), kind: .before, visibility: .portfolio)
        #expect(added)
        let photo = try #require(world.model.photos.first)
        #expect(photo.photo.visibility == .professionalOnly && photo.photo.recordID == world.model.savedRecord?.id)
        #expect(try await world.repository.photos(for: world.client.id).count == 1)
        #expect(world.model.allowedVisibilities == [.professionalOnly])
    }

    @Test("With a signed photo consent the choices open up")
    func photoWithConsent() async throws {
        let world = try await TreatmentFlowWorld.make(withPhotoConsent: true)
        #expect(world.model.hasPhotoConsent)
        await world.model.addPhoto(Data([1]), kind: .after, visibility: .shareWithClient)
        #expect(world.model.photos.first?.photo.visibility == .shareWithClient)
        let id = try #require(world.model.photos.first?.id)
        await world.model.setVisibility(.portfolio, for: id)
        #expect(world.model.photos.first?.photo.visibility == .portfolio)
        await world.model.deletePhoto(id)
        #expect(world.model.photos.isEmpty)
    }

    @Test("A picture that cannot be used says so and saves nothing")
    func photoFailure() async throws {
        let world = try await TreatmentFlowWorld.make(photoProcessing: FakePhotoProcessing(fails: true))
        let added = await world.model.addPhoto(Data([1]), kind: .before)
        #expect(!added && world.model.failure == .photo)
        #expect(try await world.repository.photos(for: world.client.id).isEmpty)
    }
}
