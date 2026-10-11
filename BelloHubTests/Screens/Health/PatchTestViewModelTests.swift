//
//  PatchTestViewModelTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@MainActor
@Suite("PatchTestViewModel")
struct PatchTestViewModelTests {
    private func makeModel(_ repository: FlakyHealthRepository, clientID: UUID) -> PatchTestViewModel {
        PatchTestViewModel(clientID: clientID, repository: repository, now: { TestClock.now }, makeID: { UUID() })
    }

    @Test("The sheet starts today, with 24 hours and no reaction, and cannot be saved without a product")
    func startsOnToday() {
        let model = makeModel(FlakyHealthRepository(), clientID: UUID())
        #expect(model.draft.testedAt == TestClock.now && model.draft.observedHours == 24)
        #expect(model.draft.result == .noReaction)
        #expect(!model.canSave)
        model.draft.product = "Calming serum"
        #expect(model.canSave)
    }

    @Test("Saving stores the entry for the client with what was entered")
    func saves() async throws {
        let repository = FlakyHealthRepository()
        let clientID = UUID()
        let model = makeModel(repository, clientID: clientID)
        model.draft.product = "Glycolic acid 10%"
        model.draft.area = "Inner arm"
        model.draft.observedHours = 48
        model.draft.result = .mildReaction
        model.draft.notes = "A little redness"

        await model.saveAsync()

        #expect(model.didSave && model.errorMessage == nil)
        let stored = try #require(try await repository.patchTests(for: clientID).first)
        #expect(stored.product == "Glycolic acid 10%" && stored.area == "Inner arm" && stored.observedHours == 48)
        #expect(stored.result == .mildReaction && stored.notes == "A little redness")
    }

    @Test("A failed save shows the error, and the retry updates the same entry")
    func retry() async throws {
        let repository = FlakyHealthRepository()
        let clientID = UUID()
        let model = makeModel(repository, clientID: clientID)
        model.draft.product = "Serum"
        await repository.fail(.patchTest)

        await model.saveAsync()
        #expect(!model.didSave && model.errorMessage != nil)

        await repository.fail([])
        await model.saveAsync()
        #expect(model.didSave && model.errorMessage == nil)
        #expect(try await repository.patchTests(for: clientID).count == 1)
    }
}
