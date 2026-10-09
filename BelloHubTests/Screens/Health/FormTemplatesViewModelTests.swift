//
//  FormTemplatesViewModelTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@MainActor
@Suite("FormTemplatesViewModel")
struct FormTemplatesViewModelTests {
    private struct Rig {
        let model: FormTemplatesViewModel
        let repository: FlakyHealthRepository
    }

    private func makeRig(
        professions: [ProfessionID] = [.esthetician], localeID: String = "pt-BR", vaultAvailable: Bool = true
    ) async throws -> Rig {
        let repository = FlakyHealthRepository()
        let profileRepository = InMemoryClientRecordRepository()
        await profileRepository.save(makeHealthProfile(professions: professions, localeID: localeID))
        let profile = ProfileService(vault: VaultService(repository: profileRepository))
        await profile.load()
        let model = FormTemplatesViewModel(
            repository: vaultAvailable ? repository : nil, profile: profile,
            catalogProvider: FakeHealthFormCatalogProvider(), locale: Locale(identifier: "en"),
            now: { TestClock.now }
        )
        return Rig(model: model, repository: repository)
    }

    private func question(_ key: String, in model: FormTemplatesViewModel) throws -> HealthQuestion {
        try #require(model.offered.first { $0.key == key })
    }

    // MARK: - Loading

    @Test("The first load stores her default as version 1 and shows its questions as switches")
    func firstLoad() async throws {
        let rig = try await makeRig()

        await rig.model.load()

        #expect(rig.model.hasLoaded && rig.model.errorMessage == nil)
        #expect(rig.model.currentVersion == 1 && rig.model.reviewMonths == 12)
        #expect(rig.model.enabledKeys == ["allergies", "medication", "pregnancy", "notes"])
        #expect(rig.model.offered.map(\.key) == ["allergies", "medication", "pregnancy", "sunExposure", "notes"])
        #expect(try await rig.repository.healthFormTemplates().count == 1)
        #expect(!rig.model.hasChanges && !rig.model.canSave && !rig.model.didSave)
    }

    @Test("A load that fails says so and a retry recovers; a missing vault is an error too")
    func loadFailure() async throws {
        let rig = try await makeRig()
        await rig.repository.fail(.reads)
        await rig.model.load()
        #expect(rig.model.errorMessage != nil && !rig.model.hasLoaded)

        await rig.repository.fail([])
        await rig.model.load()
        #expect(rig.model.errorMessage == nil && rig.model.hasLoaded)

        let noVault = try await makeRig(vaultAvailable: false)
        await noVault.model.load()
        #expect(noVault.model.errorMessage != nil && !noVault.model.hasLoaded)
    }

    // MARK: - Editing and saving

    @Test("Switching a question changes the version on save: version 2, in catalog order, version 1 untouched")
    func newVersion() async throws {
        let rig = try await makeRig()
        await rig.model.load()
        let sun = try question("sunExposure", in: rig.model)
        let pregnancy = try question("pregnancy", in: rig.model)

        rig.model.setOn(true, for: sun)
        rig.model.setOn(false, for: pregnancy)
        #expect(rig.model.isOn(sun) && !rig.model.isOn(pregnancy) && rig.model.hasChanges && rig.model.canSave)
        await rig.model.saveAsync()

        #expect(rig.model.didSave && rig.model.currentVersion == 2 && rig.model.errorMessage == nil)
        let stored = try await rig.repository.healthFormTemplates()
        #expect(stored.map(\.version) == [1, 2])
        #expect(stored[0].questionKeys == ["allergies", "medication", "pregnancy", "notes"])
        #expect(stored[1].questionKeys == ["allergies", "medication", "sunExposure", "notes"])
        #expect(!rig.model.hasChanges && !rig.model.canSave)
    }

    @Test("Changing only how often she asks again updates version 1 and does not create a version")
    func monthsOnly() async throws {
        let rig = try await makeRig()
        await rig.model.load()

        rig.model.reviewMonths = 6
        #expect(rig.model.hasChanges)
        await rig.model.saveAsync()

        let stored = try await rig.repository.healthFormTemplates()
        #expect(stored.map(\.version) == [1] && stored.first?.reviewEveryMonths == 6)
        #expect(rig.model.didSave)
    }

    @Test("Saved reads until she changes something again")
    func savedResets() async throws {
        let rig = try await makeRig()
        await rig.model.load()
        rig.model.reviewMonths = 24
        await rig.model.saveAsync()
        #expect(rig.model.didSave)

        rig.model.reviewMonths = 3
        #expect(!rig.model.didSave && rig.model.hasChanges)
    }

    @Test("A change put back the way it was is no change")
    func revertedChange() async throws {
        let rig = try await makeRig()
        await rig.model.load()
        let pregnancy = try question("pregnancy", in: rig.model)

        rig.model.setOn(false, for: pregnancy)
        rig.model.setOn(true, for: pregnancy)

        #expect(!rig.model.hasChanges && !rig.model.canSave)
    }

    @Test("At least one question must stay on: with none, saving is off and the hint is shown")
    func needsOneQuestion() async throws {
        let rig = try await makeRig()
        await rig.model.load()

        for question in rig.model.offered { rig.model.setOn(false, for: question) }

        #expect(rig.model.hasNoQuestionsOn && !rig.model.canSave)
        rig.model.setOn(true, for: try question("medication", in: rig.model))
        #expect(!rig.model.hasNoQuestionsOn && rig.model.canSave)
    }

    @Test("A save that fails shows the error and keeps what was stored")
    func saveFailure() async throws {
        let rig = try await makeRig()
        await rig.model.load()
        rig.model.setOn(true, for: try question("sunExposure", in: rig.model))
        await rig.repository.fail(.template)

        await rig.model.saveAsync()

        #expect(!rig.model.didSave && rig.model.errorMessage != nil && rig.model.currentVersion == 1)
        await rig.repository.fail([])
        #expect(try await rig.repository.healthFormTemplates().count == 1)
        await rig.model.saveAsync()
        #expect(rig.model.didSave && rig.model.currentVersion == 2)
    }

    @Test("A profession she works in brings its questions into the list")
    func professionsDecideTheList() async throws {
        let rig = try await makeRig(professions: [.hair])
        await rig.model.load()

        #expect(rig.model.offered.map(\.key) == ["allergies", "medication", "scalp", "notes"])
        #expect(rig.model.enabledKeys == ["allergies", "medication", "scalp", "notes"])
    }
}
