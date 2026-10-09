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

    // MARK: - Saving

    @Test("A complete draft can be saved")
    func canSave() {
        #expect(HealthFormFillRules.canSave(draft: allAnswered(), questions: questions))
    }

    @Test("Each missing piece blocks the save: an answer, and for a minor her name")
    func whatBlocks() {
        var missingAnswer = allAnswered()
        missingAnswer.answers["pregnancy"] = nil
        var minorWithoutName = allAnswered()
        minorWithoutName.isForMinor = true

        for draft in [missingAnswer, minorWithoutName] {
            #expect(!HealthFormFillRules.canSave(draft: draft, questions: questions))
        }
        var minor = minorWithoutName
        minor.minorName = "Ana Costa"
        #expect(HealthFormFillRules.canSave(draft: minor, questions: questions))
        #expect(HealthFormFillRules.canSave(draft: allAnswered(), questions: questions),
                "no agreement and no signature are asked (D55)")
    }

    @Test("A name needs two characters once the spaces are gone")
    func names() {
        #expect(!HealthFormFillRules.isValidName("") && !HealthFormFillRules.isValidName("   "))
        #expect(!HealthFormFillRules.isValidName(" A "))
        #expect(HealthFormFillRules.isValidName("Al") && HealthFormFillRules.isValidName("  Ana Costa "))
    }

    // MARK: - Record

    private func saving() -> HealthFormFillRules.Saving {
        HealthFormFillRules.Saving(
            client: Client(name: "Ana Costa", createdAt: TestClock.days(-100)),
            template: makeHealthTemplate(version: 4, keys: ["allergies", "medication", "notes"]),
            questions: ["allergies", "medication", "notes"].compactMap { catalog.question(for: $0) },
            formID: UUID(), now: TestClock.now
        )
    }

    @Test("A save makes a form on the template's version, filled in by the professional, with trimmed notes")
    func adultRecord() {
        var draft = allAnswered()
        draft.answers["notes"] = .text("  Keloid scars on the left cheek  ")
        let saving = saving()

        let form = HealthFormFillRules.form(draft: draft, saving: saving)

        #expect(form.formVersion == 4 && form.filledBy == .professional)
        #expect(form.signedAt == TestClock.now && form.clientID == saving.client.id)
        #expect(!form.isForMinor && form.minorName == nil)
        #expect(form.answers["notes"] == .text("Keloid scars on the left cheek"))
        #expect(form.id == saving.formID)
    }

    @Test("A minor's form says so and carries the young person's name, nothing about a guardian (D17, D55)")
    func minorRecord() {
        var draft = allAnswered()
        draft.isForMinor = true
        draft.minorName = " Ana Costa "

        let form = HealthFormFillRules.form(draft: draft, saving: saving())

        #expect(form.isForMinor && form.minorName == "Ana Costa")
    }

    @Test("Answers to questions that are off, and a note nobody wrote, are never stored")
    func onlyAskedQuestions() {
        var draft = allAnswered()
        draft.answers["pregnancy"] = .yes
        draft.answers["notes"] = .text("   ")

        let form = HealthFormFillRules.form(draft: draft, saving: saving())

        #expect(form.answers["pregnancy"] == nil, "pregnancy is not in this template")
        #expect(form.answers["notes"] == nil)
        #expect(Set(form.answers.keys) == ["allergies", "medication"])
    }
}
