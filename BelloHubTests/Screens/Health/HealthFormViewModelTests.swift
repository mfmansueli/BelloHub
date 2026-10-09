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

    private func legalTexts(_ localizations: [String] = ["en", "pt-BR"]) -> FakeLegalTextLibrary {
        FakeLegalTextLibrary(localizations.flatMap { localization in
            LegalDocument.allCases.map { FakeLegalTextLibrary.text($0, localization: localization) }
        })
    }

    private func makeRig(
        keys: [String] = ["allergies", "medication", "pregnancy", "notes"],
        library: FakeLegalTextLibrary? = nil,
        profile: ProfessionalProfile? = makeHealthProfile(localeID: "pt-BR")
    ) async throws -> Rig {
        let repository = FlakyHealthRepository()
        let client = Client(name: "Ana Costa", createdAt: TestClock.days(-100))
        try await repository.save(client)
        let model = HealthFormViewModel(
            client: client, template: makeHealthTemplate(version: 3, keys: keys), catalog: makeHealthCatalog(),
            repository: repository, legal: library ?? legalTexts(), profile: profile, fallbackLanguage: .en,
            now: { TestClock.now }, makeID: { UUID() }
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
        model.draft.agrees = true
        model.draft.signature = "Ana Costa"
    }

    // MARK: - Questions and text

    @Test("The sheet asks the template's questions in its order and skips a key this version does not know")
    func questions() async throws {
        let rig = try await makeRig(keys: ["notes", "fromTheFuture", "allergies"])
        #expect(rig.model.questions.map(\.key) == ["notes", "allergies"])
    }

    @Test("The text is read in the business language and carries her name")
    func textInBusinessLanguage() async throws {
        let rig = try await makeRig()

        #expect(rig.model.textLanguage == .ptBR)
        #expect(rig.model.legalText?.document == .consentHealth && rig.model.legalText?.localization == "pt-BR")
        let rendered = try #require(rig.model.renderedText)
        #expect(rendered.blocks.contains(.paragraph("**Who.** Maria Beauty.")))
        #expect(!rig.model.hasTextError)
    }

    @Test("Without a profile the text is read in the language of the screen")
    func fallbackLanguage() async throws {
        let rig = try await makeRig(profile: nil)
        #expect(rig.model.textLanguage == .en)
    }

    @Test("A language with no text falls back to English, and the consent will say English")
    func englishFallback() async throws {
        let rig = try await makeRig(library: legalTexts(["en"]))
        #expect(rig.model.textLanguage == .ptBR)
        #expect(rig.model.legalText?.localization == "en")

        answerEverything(rig.model)
        await rig.model.saveAsync()

        #expect(try await rig.repository.consents(for: rig.client.id).first?.localeID == "en")
    }

    @Test("Choosing another language reads that text and asks for the agreement again")
    func changingLanguage() async throws {
        let rig = try await makeRig()
        rig.model.draft.agrees = true

        rig.model.setTextLanguage(.en)

        #expect(rig.model.legalText?.localization == "en" && !rig.model.draft.agrees)
        rig.model.draft.agrees = true
        rig.model.setTextLanguage(.en)
        #expect(rig.model.draft.agrees, "choosing the same language changes nothing")
    }

    @Test("A visit for someone under 18 switches to the guardian text and asks for the agreement again (D17)")
    func minorSwitchesText() async throws {
        let rig = try await makeRig()
        rig.model.draft.agrees = true
        #expect(rig.model.consentKind == .treatment)

        rig.model.setForMinor(true)

        #expect(rig.model.consentKind == .guardian && rig.model.legalText?.document == .consentGuardian)
        #expect(!rig.model.draft.agrees)
        rig.model.setForMinor(false)
        #expect(rig.model.legalText?.document == .consentHealth)
    }

    @Test("Without a text nothing can be signed, however complete the answers are")
    func noText() async throws {
        let rig = try await makeRig(library: FakeLegalTextLibrary())
        #expect(rig.model.hasTextError && rig.model.renderedText == nil)

        answerEverything(rig.model)

        #expect(!rig.model.canSave)
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

    @Test("Save stays off until everything is answered, agreed and signed")
    func canSave() async throws {
        let rig = try await makeRig()
        #expect(!rig.model.canSave)
        answerEverything(rig.model)
        #expect(rig.model.canSave)
        rig.model.draft.signature = ""
        #expect(!rig.model.canSave)
    }

    @Test("Saving writes the consent on the text that was read and the form on the template's version")
    func saves() async throws {
        let rig = try await makeRig()
        answerEverything(rig.model)

        await rig.model.saveAsync()

        #expect(rig.model.didSave && rig.model.errorMessage == nil && !rig.model.isSaving)
        let consent = try #require(try await rig.repository.consents(for: rig.client.id).first)
        #expect(consent.kind == .treatment && consent.textVersion == "2026-10" && consent.localeID == "pt-BR")
        #expect(consent.typedSignature == "Ana Costa" && consent.signedAt == TestClock.now)
        let form = try #require(try await rig.repository.healthForms(for: rig.client.id).first)
        #expect(form.formVersion == 3 && form.filledBy == .professional && form.signedAt == TestClock.now)
        #expect(form.answers["medication"] == .no && form.answers["allergies"] == .choices(["none"]))
    }

    @Test("A minor's form is saved with the guardian consent and both names")
    func savesMinor() async throws {
        let rig = try await makeRig()
        rig.model.setForMinor(true)
        answerEverything(rig.model)
        rig.model.draft.minorName = "Ana Costa"
        rig.model.draft.signature = "Rita Costa"

        await rig.model.saveAsync()

        let consent = try #require(try await rig.repository.consents(for: rig.client.id).first)
        #expect(consent.kind == .guardian && consent.typedSignature == "Rita Costa")
        let form = try #require(try await rig.repository.healthForms(for: rig.client.id).first)
        #expect(form.isForMinor && form.guardianName == "Rita Costa" && form.minorName == "Ana Costa")
    }

    @Test("If the form cannot be saved the error shows, and trying again adds no second consent")
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
        #expect(try await rig.repository.consents(for: rig.client.id).count == 1, "the retry updated the same consent")
        #expect(try await rig.repository.healthForms(for: rig.client.id).count == 1)
    }

    @Test("If the consent cannot be saved no answers are saved either")
    func consentFirst() async throws {
        let rig = try await makeRig()
        answerEverything(rig.model)
        await rig.repository.fail(.consent)

        await rig.model.saveAsync()

        #expect(!rig.model.didSave && rig.model.errorMessage != nil)
        #expect(await rig.repository.savedForms == 0, "answers are never stored without their consent")
    }
}
