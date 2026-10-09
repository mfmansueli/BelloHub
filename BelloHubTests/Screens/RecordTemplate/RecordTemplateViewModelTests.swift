//
//  RecordTemplateViewModelTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import os
import Testing

private typealias Fixtures = TagsRecordFixtures

/// Ids that count up, so the key of each field a test adds is known and different.
private final class SequentialIDs: Sendable {
    private let counter = OSAllocatedUnfairLock(initialState: 0)

    func make() -> UUID {
        let number = counter.withLock { value -> Int in
            value += 1
            return value
        }
        return UUID(uuidString: String(format: "00000000-0000-4000-8000-%012d", number)) ?? UUID()
    }

    static func key(_ number: Int) -> String {
        "custom-" + String(format: "00000000-0000-4000-8000-%012d", number)
    }
}

@MainActor
@Suite("RecordTemplateViewModel")
struct RecordTemplateViewModelTests {
    private struct Rig {
        let model: RecordTemplateViewModel
        let profile: ProfileService
        let repository: FakeBusinessRepository
    }

    /// A model over a repository that can be told to fail, with an esthetician (and, with `twoProfessions`, a hair
    /// stylist) set up the way onboarding would have saved her.
    private func makeRig(twoProfessions: Bool = false) async -> Rig {
        let repository = FakeBusinessRepository()
        await repository.seed(Fixtures.result(professions: twoProfessions ? [.esthetician, .hair] : [.esthetician]))
        let profile = ProfileService(repository: repository)
        await profile.load()
        let ids = SequentialIDs()
        let model = RecordTemplateViewModel(
            profile: profile, catalog: makeCatalog(), now: { TestClock.now }, makeID: { ids.make() }
        )
        return Rig(model: model, profile: profile, repository: repository)
    }

    private func draft(_ name: String, kind: RecordFieldKind = .text, options: String = "") -> RecordFieldDraft {
        RecordTemplateFixtures.draft(name, kind: kind, options: options)
    }

    private func names(_ rig: Rig) -> [String] {
        rig.model.customFields(for: .esthetician).map { rig.model.name(of: $0) }
    }

    private func storedKeys(_ rig: Rig) async -> [String] {
        await rig.repository.storedRecordTemplate()?.fields.map(\.key) ?? []
    }

    private func storedOn(_ rig: Rig) async -> [String]? {
        await rig.repository.storedRecordTemplate()?.enabledKeys(for: .esthetician)
    }

    // MARK: - Reading

    @Test("It starts on her first profession with the catalog's names and what is switched on")
    func initialState() async {
        let rig = await makeRig(twoProfessions: true)
        let model = rig.model

        #expect(model.professions == [.esthetician, .hair])
        #expect(model.selectedProfession == .esthetician)
        #expect(model.professionName(.hair) == "Hair stylist")
        let standard = model.standardFields(for: .esthetician)
        #expect(standard.map { model.name(of: $0) } == ["Skin condition", "Technique"])
        #expect(standard.map(\.isOn) == [true, false])
        #expect(model.counts(for: .esthetician) == (on: 1, total: 2))
        #expect(model.customFields(for: .esthetician).isEmpty && model.canAddField(for: .esthetician))
        #expect(model.isIntakeOn(.healthHistory, for: .esthetician))
        #expect(!model.isIntakeOn(.patchTestLog, for: .esthetician))
        #expect(model.clientTerm == .client)
    }

    @Test("Choosing another profession shows its fields; one she does not have is ignored")
    func selectsAProfession() async {
        let rig = await makeRig(twoProfessions: true)

        rig.model.select(.hair)
        #expect(rig.model.selectedProfession == .hair)
        #expect(rig.model.standardFields(for: .hair).map { rig.model.name(of: $0) } == ["Formula"])

        rig.model.select(.tattoo)
        #expect(rig.model.selectedProfession == .esthetician)
    }

    @Test("A profession whose fields were never saved is topped up from the catalog, without writing anything")
    func completesWhatIsMissing() async {
        let repository = FakeBusinessRepository()
        let setup = Fixtures.result(professions: [.esthetician, .hair])
        // As if the hair profession was added after the setup: the profile has it, the template does not.
        let partial = RecordTemplate(
            fields: setup.template.fields.filter { $0.profession == .esthetician }, intake: [],
            updatedAt: TestClock.now
        )
        await repository.seed(OnboardingResult(profile: setup.profile, services: [], tags: [], template: partial))
        let profile = ProfileService(repository: repository)
        await profile.load()

        let model = RecordTemplateViewModel(profile: profile, catalog: makeCatalog())

        #expect(model.standardFields(for: .hair).map(\.key) == ["hair.formula"])
        #expect(model.isIntakeOn(.patchTestLog, for: .hair))
        #expect(await repository.writeCount == 0)
    }

    // MARK: - Switches

    @Test("A switch moves at once and is written to the vault")
    func switchesAreSaved() async {
        let rig = await makeRig()

        rig.model.setField("est.technique", on: true)

        #expect(rig.model.counts(for: .esthetician).on == 2, "the screen does not wait for the vault")
        #expect(await Wait.until { await storedOn(rig) == ["est.skin", "est.technique"] })
        await Wait.untilMain { rig.profile.template?.enabledKeys(for: .esthetician).count == 2 }
        #expect(rig.profile.template?.enabledKeys(for: .esthetician) == ["est.skin", "est.technique"])
    }

    @Test("Several quick switches all reach the vault, in order, and the last word wins")
    func quickSwitches() async {
        let rig = await makeRig()

        rig.model.setField("est.technique", on: true)
        rig.model.setField("est.skin", on: false)
        rig.model.setIntake(.patchTestLog, on: true)
        rig.model.setField("est.skin", on: true)

        #expect(await Wait.until {
            let stored = await rig.repository.storedRecordTemplate()
            return stored?.enabledKeys(for: .esthetician) == ["est.skin", "est.technique"]
                && stored?.isIntakeOn(.patchTestLog, for: .esthetician) == true
        })
        #expect(rig.model.errorMessage == nil)
    }

    @Test("Switching a field to the state it is in writes nothing")
    func noOpSwitches() async {
        let rig = await makeRig()
        let before = await rig.repository.writeCount

        rig.model.setField("est.skin", on: true)
        rig.model.setField("nope", on: true)
        rig.model.setIntake(.healthHistory, on: true)
        await Wait.untilMain { !rig.model.isSaving }

        #expect(await rig.repository.writeCount == before)
    }

    @Test("Switches apply to the selected profession")
    func switchesFollowTheSelection() async {
        let rig = await makeRig(twoProfessions: true)
        rig.model.select(.hair)

        rig.model.setField("hair.formula", on: false)
        rig.model.setIntake(.healthHistory, on: true)

        #expect(await Wait.until {
            let stored = await rig.repository.storedRecordTemplate()
            return stored?.enabledKeys(for: .hair) == [] && stored?.enabledKeys(for: .esthetician) == ["est.skin"]
                && stored?.isIntakeOn(.healthHistory, for: .hair) == true
        })
    }

    // MARK: - Fields of her own

    @Test("A new field is saved with its stable key and shows in her list")
    func addsAField() async throws {
        let rig = await makeRig()

        let saved = await rig.model.addField(draft("Mood today"))

        #expect(saved)
        let field = try #require(rig.model.customFields(for: .esthetician).first)
        #expect(field.key == SequentialIDs.key(1) && rig.model.name(of: field) == "Mood today")
        #expect(await storedKeys(rig) == ["est.skin", "est.technique", SequentialIDs.key(1)])
        #expect(rig.profile.template?.fields.count == 3)
        #expect(!rig.model.isSaving)
    }

    @Test("A field that is not valid is not added and nothing is written")
    func refusesAnInvalidField() async {
        let rig = await makeRig()
        let before = await rig.repository.writeCount

        let empty = await rig.model.addField(draft(""))
        let taken = await rig.model.addField(draft("technique"))
        let thin = await rig.model.addField(draft("Finish", kind: .choice, options: "Only one"))

        #expect(!empty && !taken && !thin)
        #expect(rig.model.issue(in: draft("technique")) == .nameTaken)
        #expect(rig.model.issue(in: draft("Mood")) == nil)
        #expect(await rig.repository.writeCount == before)
        #expect(rig.model.errorMessage == nil)
    }

    @Test("A field of hers can be renamed and deleted")
    func editsFields() async throws {
        let rig = await makeRig()
        #expect(await rig.model.addField(draft("Mood")))
        #expect(await rig.model.addField(draft("Energy")))
        let first = SequentialIDs.key(1)
        let second = SequentialIDs.key(2)

        let renamed = await rig.model.updateField(first, with: draft("Daily mood"))

        #expect(renamed && names(rig) == ["Daily mood", "Energy"])
        #expect(rig.model.issue(in: draft("daily mood"), editing: first) == nil)
        #expect(rig.model.issue(in: draft("energy"), editing: first) == .nameTaken)
        #expect(await rig.model.deleteField(second))
        #expect(names(rig) == ["Daily mood"])
        #expect(await storedKeys(rig) == ["est.skin", "est.technique", first])
    }

    @Test("Her fields can be dragged, and the order is saved")
    func movesFields() async {
        let rig = await makeRig()
        for name in ["A", "B", "C"] { #expect(await rig.model.addField(draft(name))) }
        #expect(names(rig) == ["A", "B", "C"])

        rig.model.moveFields(from: [0], to: 3)

        #expect(names(rig) == ["B", "C", "A"])
        #expect(await Wait.until {
            await rig.repository.storedRecordTemplate()?.fields.compactMap(\.customName) == ["B", "C", "A"]
        })
    }

    // MARK: - Loading

    @Test("Reading again shows what another screen or device saved")
    func reloads() async throws {
        let rig = await makeRig()
        var changed = try #require(await rig.repository.storedRecordTemplate())
        changed.fields[1].isOn = true
        await rig.repository.seedTemplate(changed)

        await rig.model.loadAsync()

        #expect(rig.model.counts(for: .esthetician).on == 2)
        #expect(rig.model.errorMessage == nil && !rig.model.isLoading)
    }

    @Test("When the vault cannot be read the screen says so")
    func loadFailure() async {
        let profile = ProfileService(vault: VaultService(repository: nil))
        let model = RecordTemplateViewModel(profile: profile, catalog: makeCatalog())

        await model.loadAsync()

        #expect(model.errorMessage != nil && !model.isLoading)
        #expect(model.selectedProfession == nil)
        model.dismissError()
        #expect(model.errorMessage == nil)
    }

    // MARK: - When saving fails

    @Test("A switch the vault refuses goes back, and the screen says what happened")
    func failedSwitch() async {
        let rig = await makeRig()
        await rig.repository.setFailsWrites(true)

        rig.model.setField("est.technique", on: true)

        await Wait.untilMain { rig.model.errorMessage != nil }
        #expect(rig.model.errorMessage != nil)
        #expect(rig.model.counts(for: .esthetician).on == 1, "the switch is back where the vault has it")
        #expect(rig.profile.template?.enabledKeys(for: .esthetician) == ["est.skin"])
        #expect(await storedOn(rig) == ["est.skin"])
    }

    @Test("A field the vault refuses is not kept, and adding fails")
    func failedAdd() async {
        let rig = await makeRig()
        await rig.repository.setFailsWrites(true)

        let saved = await rig.model.addField(draft("Mood"))

        #expect(!saved && rig.model.errorMessage != nil)
        #expect(rig.model.customFields(for: .esthetician).isEmpty)
        #expect(await storedKeys(rig) == ["est.skin", "est.technique"])
    }

    @Test("Once the vault says yes again the next change goes through and clears the error")
    func recovery() async {
        let rig = await makeRig()
        await rig.repository.setFailsWrites(true)
        rig.model.setField("est.technique", on: true)
        await Wait.untilMain { rig.model.errorMessage != nil }
        await rig.repository.setFailsWrites(false)

        rig.model.setField("est.technique", on: true)

        #expect(await Wait.until { await storedOn(rig) == ["est.skin", "est.technique"] })
        #expect(rig.model.errorMessage == nil)
    }
}
