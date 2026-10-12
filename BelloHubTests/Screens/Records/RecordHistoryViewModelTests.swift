//
//  RecordHistoryViewModelTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@MainActor
@Suite("RecordHistoryViewModel", .serialized)
struct RecordHistoryViewModelTests {
    private struct World {
        let model: RecordHistoryViewModel
        let repository: any ClientRecordRepository
        let client: Client
        let locked: TreatmentRecord
        let open: TreatmentRecord
    }

    private func makeWorld(withPhotoConsent: Bool = false, photos: [Photo] = []) async throws -> World {
        let world = try await ClientsWorld.make()
        let client = makeClient(name: "Ana Costa")
        _ = try await world.repository.save(client)
        let locked = makeRecord(
            clientID: client.id, serviceName: "Locked facial", createdAt: TestClock.days(-3), aftercare: "Original"
        )
        let open = makeRecord(
            clientID: client.id, serviceName: "Open facial", createdAt: TestClock.now.addingTimeInterval(-3600)
        )
        try await world.repository.save(locked)
        try await world.repository.save(open)
        if withPhotoConsent { try await world.repository.save(makeConsent(clientID: client.id, kind: .photos)) }
        for photo in photos {
            var stored = photo
            stored.clientID = client.id
            try await world.repository.save(stored, data: PhotoData(image: Data([1]), thumbnail: Data([2])))
        }
        let ids = [UUID(), UUID(), UUID()]
        let counter = IDCounter(ids)
        let model = RecordHistoryViewModel(
            clientID: client.id, vault: world.vault, profile: world.profile, now: { TestClock.now },
            makeID: { counter.next() }
        )
        await model.loadAsync()
        return World(model: model, repository: world.repository, client: client, locked: locked, open: open)
    }

    // MARK: - Loading

    @Test("The edit trail names her even when the profile arrives after the screen opened")
    func nameFollowsTheProfile() async throws {
        let repository: any ClientRecordRepository = InMemoryClientRecordRepository(clock: { TestClock.now })
        let vault = VaultService(repository: repository)
        let profile = ProfileService(vault: vault)
        let client = makeClient(name: "Ana Costa")
        _ = try await repository.save(client)
        let model = RecordHistoryViewModel(clientID: client.id, vault: vault, profile: profile, now: { TestClock.now })
        await model.loadAsync()
        #expect(model.professionalName.isEmpty)

        try await repository.save(makeHealthProfile(name: "Maria Silva"))
        await profile.load()

        #expect(model.professionalName == "Maria")
    }

    @Test("The history opens with her records newest first and their lock state")
    func loads() async throws {
        let world = try await makeWorld()
        #expect(world.model.client?.name == "Ana Costa")
        #expect(world.model.items.map(\.record.serviceName) == ["Open facial", "Locked facial"])
        #expect(world.model.items.map(\.isLocked) == [false, true])
        #expect(world.model.isLoading == false)
        #expect(world.model.errorMessage == nil)
    }

    @Test("A client who is gone is said, not crashed on")
    func clientMissing() async throws {
        let world = try await ClientsWorld.make()
        let model = RecordHistoryViewModel(clientID: UUID(), vault: world.vault, profile: world.profile)
        await model.loadAsync()
        #expect(model.isMissing)
        #expect(model.client == nil)
    }

    @Test("A vault that cannot be opened is an error with a message")
    func vaultUnavailable() async throws {
        let world = try await ClientsWorld.make()
        let model = RecordHistoryViewModel(
            clientID: UUID(), vault: VaultService(repository: nil), profile: world.profile
        )
        await model.loadAsync()
        #expect(model.errorMessage != nil)
        #expect(model.isLoading == false)
    }

    // MARK: - Corrections

    @Test("Starting a correction fills the box with what the field says now")
    func beginCorrection() async throws {
        let world = try await makeWorld()
        world.model.beginCorrection(for: world.locked.id)
        world.model.selectField(.standard(.aftercare))
        #expect(world.model.draft?.newValue == "Original")
        #expect(world.model.draftPath == .addCorrection)
        #expect(world.model.draftCurrentValue == "Original")
    }

    @Test("On a locked record a correction without a reason is turned away and nothing is written")
    func correctionNeedsReason() async throws {
        let world = try await makeWorld()
        world.model.beginCorrection(for: world.locked.id)
        world.model.selectField(.standard(.aftercare))
        world.model.draft?.newValue = "Gentle cleansing for 48 hours"
        await world.model.saveCorrectionAsync()
        #expect(world.model.draftProblem == .reasonMissing)
        #expect(world.model.draft != nil)
        #expect(try await world.repository.corrections(for: world.locked.id).isEmpty)
    }

    @Test("A correction on a locked record is logged, the original stays and the trail grows")
    func correctionIsLogged() async throws {
        let world = try await makeWorld()
        world.model.beginCorrection(for: world.locked.id)
        world.model.selectField(.standard(.aftercare))
        world.model.draft?.newValue = "Gentle cleansing for 48 hours"
        world.model.draft?.reason = "Forgot to write it"
        await world.model.saveCorrectionAsync()
        #expect(world.model.draft == nil)
        let corrections = try await world.repository.corrections(for: world.locked.id)
        #expect(corrections.count == 1)
        #expect(corrections.first?.oldValue == "Original")
        #expect(corrections.first?.newValue == "Gentle cleansing for 48 hours")
        #expect(corrections.first?.reason == "Forgot to write it")
        let stored = try await world.repository.record(id: world.locked.id)
        #expect(stored?.aftercare == "Original")
        let item = world.model.items.first { $0.id == world.locked.id }
        #expect(item?.trail.count == 3) // correction, locked, created
        #expect(item.map { RecordEditRules.currentValue(of: .aftercare, in: $0.record, corrections: $0.corrections) }
            == "Gentle cleansing for 48 hours")
    }

    @Test("A record that is still open is edited directly, with no correction and no reason")
    func openRecordIsEdited() async throws {
        let world = try await makeWorld()
        world.model.beginCorrection(for: world.open.id)
        world.model.selectField(.standard(.technique))
        world.model.draft?.newValue = "Microneedling"
        await world.model.saveCorrectionAsync()
        #expect(world.model.draft == nil)
        let stored = try await world.repository.record(id: world.open.id)
        #expect(stored?.technique == "Microneedling")
        #expect(try await world.repository.corrections(for: world.open.id).isEmpty)
    }

    @Test("The same text is not saved")
    func unchangedIsRefused() async throws {
        let world = try await makeWorld()
        world.model.beginCorrection(for: world.open.id)
        world.model.selectField(.standard(.technique))
        await world.model.saveCorrectionAsync()
        #expect(world.model.draftProblem == .unchanged)
    }

    @Test("Cancelling closes the sheet and writes nothing")
    func cancel() async throws {
        let world = try await makeWorld()
        world.model.beginCorrection(for: world.locked.id)
        world.model.cancelCorrection()
        #expect(world.model.draft == nil)
        #expect(try await world.repository.corrections(for: world.locked.id).isEmpty)
    }

    // MARK: - Photos

    @Test("Without a photo consent a photo cannot be made visible to anyone else")
    func visibilityNeedsConsent() async throws {
        let photo = makePhoto(kind: .before, visibility: .professionalOnly)
        let world = try await makeWorld(photos: [photo])
        let loaded = try #require(world.model.photos.first)
        #expect(world.model.hasPhotoConsent == false)
        #expect(world.model.visibilityOptions(for: loaded) == [.professionalOnly])
        await world.model.setVisibilityAsync(.shareWithClient, of: loaded)
        #expect(try await world.repository.photos(for: world.client.id).first?.visibility == .professionalOnly)
    }

    @Test("With a photo consent the visibility changes and the picture is kept")
    func visibilityWithConsent() async throws {
        let photo = makePhoto(kind: .after, visibility: .professionalOnly)
        let world = try await makeWorld(withPhotoConsent: true, photos: [photo])
        let loaded = try #require(world.model.photos.first)
        #expect(world.model.hasPhotoConsent)
        await world.model.setVisibilityAsync(.shareWithClient, of: loaded)
        let stored = try await world.repository.photos(for: world.client.id).first
        #expect(stored?.visibility == .shareWithClient)
        #expect(try await world.repository.photoData(id: loaded.id).image == Data([1]))
        #expect(world.model.photos.first?.visibility == .shareWithClient)
    }

    @Test("Photo bytes are read once and kept while the screen is open")
    func imageCache() async throws {
        let photo = makePhoto(kind: .before)
        let world = try await makeWorld(photos: [photo])
        let loaded = try #require(world.model.photos.first)
        let first = await world.model.imageData(for: loaded)
        #expect(first?.thumbnail == Data([2]))
        try await world.repository.deletePhoto(id: loaded.id)
        #expect(await world.model.imageData(for: loaded)?.thumbnail == Data([2]))
    }
}
