//
//  HealthFormViewModelTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@MainActor
@Suite("HealthFormViewModel")
struct HealthFormViewModelTests {
    private struct Rig {
        let model: HealthFormViewModel
        let repository: FlakyHealthRepository
        let client: Client
    }

    private func makeRig(keys: [String] = ["allergies", "medication", "pregnancy", "notes"]) async throws -> Rig {
        let repository = FlakyHealthRepository()
        let client = Client(name: "Ana Costa", createdAt: TestClock.days(-100))
        try await repository.save(client)
        let model = HealthFormViewModel(
            client: client, template: makeHealthTemplate(version: 3, keys: keys), catalog: makeHealthCatalog(),
            repository: repository, now: { TestClock.now }, makeID: { UUID() }
        )
        return Rig(model: model, repository: repository, client: client)
    }

    private func answerEverything(_ model: HealthFormViewModel) {
        for question in model.questions {
            switch question.kind {
            case .yesNo: model.setYesNo(false, for: question)
            case .choices: model.toggleChoice(HealthOption.noneKey, for: question)
            case .text: break
            }
        }
    }

    // MARK: - Questions

    @Test("The sheet asks the template's questions in its order and skips a key this version does not know")
    func questions() async throws {
        let rig = try await makeRig(keys: ["notes", "fromTheFuture", "allergies"])
        #expect(rig.model.questions.map(\.key) == ["notes", "allergies"])
    }

    @Test("A visit for someone under 18 only marks the form (D17); switching back clears nothing else")
    func minor() async throws {
        let rig = try await makeRig()
        answerEverything(rig.model)

        rig.model.setForMinor(true)
        #expect(rig.model.draft.isForMinor && !rig.model.canSave, "the young person's name is missing")
        rig.model.draft.minorName = "Ana Costa"
        #expect(rig.model.canSave)
        rig.model.setForMinor(false)
        #expect(!rig.model.draft.isForMinor && rig.model.canSave)
    }

    // MARK: - Answers

    @Test("Answers are set, changed and read back; an empty note is no answer")
    func answers() async throws {
        let rig = try await makeRig()
        let medication = try #require(rig.model.questions.first { $0.key == "medication" })
        let allergies = try #require(rig.model.questions.first { $0.key == "allergies" })
        let notes = try #require(rig.model.questions.first { $0.key == "notes" })

        rig.model.setYesNo(true, for: medication)
        #expect(rig.model.answer(for: medication) == .yes)
        rig.model.setYesNo(false, for: medication)
        #expect(rig.model.answer(for: medication) == .no)

        rig.model.toggleChoice("latex", for: allergies)
        #expect(rig.model.isChoiceOn("latex", for: allergies) && !rig.model.isChoiceOn("retinol", for: allergies))

        rig.model.setText("Sensitive eyes", for: notes)
        #expect(rig.model.text(for: notes) == "Sensitive eyes")
        rig.model.setText("", for: notes)
        #expect(rig.model.answer(for: notes) == nil)
    }

    // MARK: - Saving

    @Test("Save stays off until everything is answered; no agreement and no signature are asked (D55)")
    func canSave() async throws {
        let rig = try await makeRig()
        #expect(!rig.model.canSave)
        answerEverything(rig.model)
        #expect(rig.model.canSave)
    }

    @Test("Saving writes the form on the template's version, filled in by the professional, and no consent")
    func saves() async throws {
        let rig = try await makeRig()
        answerEverything(rig.model)

        await rig.model.saveAsync()

        #expect(rig.model.didSave && rig.model.errorMessage == nil && !rig.model.isSaving)
        let form = try #require(try await rig.repository.healthForms(for: rig.client.id).first)
        #expect(form.formVersion == 3 && form.filledBy == .professional && form.signedAt == TestClock.now)
        #expect(form.answers["medication"] == .no && form.answers["allergies"] == .choices(["none"]))
        #expect(try await rig.repository.consents(for: rig.client.id).isEmpty)
        #expect(await rig.repository.savedConsents == 0)
    }

    @Test("A minor's form is saved with the young person's name")
    func savesMinor() async throws {
        let rig = try await makeRig()
        rig.model.setForMinor(true)
        answerEverything(rig.model)
        rig.model.draft.minorName = "Ana Costa"

        await rig.model.saveAsync()

        let form = try #require(try await rig.repository.healthForms(for: rig.client.id).first)
        #expect(form.isForMinor && form.minorName == "Ana Costa")
    }

    @Test("If the form cannot be saved the error shows, and trying again updates the same record")
    func retryAfterFailure() async throws {
        let rig = try await makeRig()
        answerEverything(rig.model)
        await rig.repository.fail(.form)

        await rig.model.saveAsync()

        #expect(!rig.model.didSave && rig.model.errorMessage != nil && !rig.model.isSaving)
        #expect(try await rig.repository.healthForms(for: rig.client.id).isEmpty)

        await rig.repository.fail([])
        await rig.model.saveAsync()

        #expect(rig.model.didSave && rig.model.errorMessage == nil)
        #expect(try await rig.repository.healthForms(for: rig.client.id).count == 1)
    }
}
