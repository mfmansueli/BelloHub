//
//  HealthFormFillRulesTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@Suite("HealthFormFillRules")
struct HealthFormFillRulesTests {
    private let catalog = makeHealthCatalog()

    private var questions: [HealthQuestion] {
        ["allergies", "medication", "pregnancy", "notes"].compactMap { catalog.question(for: $0) }
    }

    private func allAnswered() -> HealthFormDraft {
        var draft = HealthFormDraft()
        draft.answers = ["allergies": .choices(["none"]), "medication": .no, "pregnancy": .no]
        draft.agrees = true
        draft.signature = "Ana Costa"
        return draft
    }

    // MARK: - Answers

    @Test("A yes or no and a choice must be given explicitly; a note is optional")
    func answeredRules() throws {
        let allergies = try #require(catalog.question(for: "allergies"))
        let medication = try #require(catalog.question(for: "medication"))
        let notes = try #require(catalog.question(for: "notes"))

        #expect(!HealthFormFillRules.isAnswered(medication, nil))
        #expect(HealthFormFillRules.isAnswered(medication, .no) && HealthFormFillRules.isAnswered(medication, .yes))
        #expect(!HealthFormFillRules.isAnswered(medication, .text("yes")))
        #expect(!HealthFormFillRules.isAnswered(allergies, nil))
        #expect(!HealthFormFillRules.isAnswered(allergies, .choices([])))
        #expect(HealthFormFillRules.isAnswered(allergies, .choices(["none"])))
        #expect(HealthFormFillRules.isAnswered(notes, nil))
    }

    @Test("The questions still waiting for an answer come in the order they are asked")
    func unanswered() {
        var draft = HealthFormDraft()
        draft.answers["medication"] = .no
        #expect(HealthFormFillRules.unansweredKeys(questions: questions, draft: draft) == ["allergies", "pregnancy"])
    }

    @Test("Ticking choices keeps them in the question's order, and ticking one again unticks it")
    func choosing() throws {
        let allergies = try #require(catalog.question(for: "allergies"))
        var answer: HealthAnswer?
        answer = HealthFormFillRules.choosing("retinol", in: answer, for: allergies)
        answer = HealthFormFillRules.choosing("fragrance", in: answer, for: allergies)
        #expect(answer == .choices(["fragrance", "retinol"]))
        answer = HealthFormFillRules.choosing("retinol", in: answer, for: allergies)
        #expect(answer == .choices(["fragrance"]))
        answer = HealthFormFillRules.choosing("fragrance", in: answer, for: allergies)
        #expect(answer == nil, "no choice left means unanswered, not an empty answer")
    }

    @Test("None is exclusive: choosing it clears the others and choosing another clears it")
    func noneIsExclusive() throws {
        let allergies = try #require(catalog.question(for: "allergies"))
        var answer = HealthFormFillRules.choosing("latex", in: nil, for: allergies)
        answer = HealthFormFillRules.choosing("fragrance", in: answer, for: allergies)
        answer = HealthFormFillRules.choosing("none", in: answer, for: allergies)
        #expect(answer == .choices(["none"]))
        answer = HealthFormFillRules.choosing("latex", in: answer, for: allergies)
        #expect(answer == .choices(["latex"]))
        answer = HealthFormFillRules.choosing("none", in: answer, for: allergies)
        answer = HealthFormFillRules.choosing("none", in: answer, for: allergies)
        #expect(answer == nil)
    }

    // MARK: - Signing

    @Test("A complete draft can be signed")
    func canSign() {
        #expect(HealthFormFillRules.canSign(draft: allAnswered(), questions: questions))
    }

    @Test("Each missing piece blocks the signature: an answer, the box, the name, and for a minor her name")
    func whatBlocks() {
        var missingAnswer = allAnswered()
        missingAnswer.answers["pregnancy"] = nil
        var notAgreed = allAnswered()
        notAgreed.agrees = false
        var shortName = allAnswered()
        shortName.signature = " A "
        var minorWithoutName = allAnswered()
        minorWithoutName.isForMinor = true

        for draft in [missingAnswer, notAgreed, shortName, minorWithoutName] {
            #expect(!HealthFormFillRules.canSign(draft: draft, questions: questions))
        }
        var minor = minorWithoutName
        minor.minorName = "Ana Costa"
        #expect(HealthFormFillRules.canSign(draft: minor, questions: questions))
    }

    @Test("A name needs two characters once the spaces are gone")
    func names() {
        #expect(!HealthFormFillRules.isValidName("") && !HealthFormFillRules.isValidName("   "))
        #expect(!HealthFormFillRules.isValidName(" A "))
        #expect(HealthFormFillRules.isValidName("Al") && HealthFormFillRules.isValidName("  Ana Costa "))
    }

    @Test("The consent is the guardian's for a minor and the treatment consent for everyone else (D17)")
    func consentKinds() {
        #expect(HealthFormFillRules.consentKind(isForMinor: true) == .guardian)
        #expect(HealthFormFillRules.consentKind(isForMinor: false) == .treatment)
    }

    // MARK: - Records

    private func signing(text: LegalText? = nil) -> HealthFormFillRules.Signing {
        HealthFormFillRules.Signing(
            client: makeClient(name: "Ana Costa"),
            template: makeHealthTemplate(version: 4, keys: ["allergies", "medication", "notes"]),
            questions: ["allergies", "medication", "notes"].compactMap { catalog.question(for: $0) },
            text: text ?? FakeLegalTextLibrary.text(.consentHealth, localization: "pt-BR", version: "2026-10"),
            formID: UUID(), consentID: UUID(), now: TestClock.now
        )
    }

    @Test("A signature makes a form on the template's version and a consent on the text that was read")
    func adultRecords() {
        var draft = allAnswered()
        draft.answers["notes"] = .text("  Keloid scars on the left cheek  ")
        draft.signature = "  Ana Costa "
        let signing = signing()

        let records = HealthFormFillRules.records(draft: draft, signing: signing)

        #expect(records.form.formVersion == 4 && records.form.filledBy == .professional)
        #expect(records.form.signedAt == TestClock.now && records.form.clientID == signing.client.id)
        #expect(!records.form.isForMinor && records.form.guardianName == nil && records.form.minorName == nil)
        #expect(records.form.answers["notes"] == .text("Keloid scars on the left cheek"))
        #expect(records.form.id == signing.formID && records.consent.id == signing.consentID)
        #expect(records.consent.kind == .treatment && records.consent.typedSignature == "Ana Costa")
        #expect(records.consent.textVersion == "2026-10" && records.consent.localeID == "pt-BR")
        #expect(records.consent.signedAt == TestClock.now && records.consent.signatureImage == nil)
    }

    @Test("A minor's form carries both names, and the guardian signs the guardian consent")
    func minorRecords() {
        var draft = allAnswered()
        draft.isForMinor = true
        draft.minorName = " Ana Costa "
        draft.signature = "Rita Costa"
        let text = FakeLegalTextLibrary.text(.consentGuardian, localization: "en", version: "2026-10")

        let records = HealthFormFillRules.records(draft: draft, signing: signing(text: text))

        #expect(records.form.isForMinor && records.form.guardianName == "Rita Costa")
        #expect(records.form.minorName == "Ana Costa")
        #expect(records.consent.kind == .guardian && records.consent.typedSignature == "Rita Costa")
        #expect(records.consent.localeID == "en")
    }

    @Test("Answers to questions that are off, and a note nobody wrote, are never stored")
    func onlyAskedQuestions() {
        var draft = allAnswered()
        draft.answers["pregnancy"] = .yes
        draft.answers["notes"] = .text("   ")

        let records = HealthFormFillRules.records(draft: draft, signing: signing())

        #expect(records.form.answers["pregnancy"] == nil, "pregnancy is not in this template")
        #expect(records.form.answers["notes"] == nil)
        #expect(Set(records.form.answers.keys) == ["allergies", "medication"])
    }
}
