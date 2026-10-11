//
//  RecordTemplateRulesTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

private typealias Fixtures = RecordTemplateFixtures

/// The validation rules of the field sheet: names, options, units and the limit on fields of her own.
@Suite("RecordTemplateEditor: rules")
struct RecordTemplateRulesTests {
    private let scope = Fixtures.scope
    private let later = Fixtures.later

    private func issue(
        _ draft: RecordFieldDraft, in template: RecordTemplate = Fixtures.makeTemplate(),
        scope: RecordTemplateEditor.Scope? = nil, editing key: String? = nil
    ) -> RecordFieldIssue? {
        RecordTemplateEditor.issue(in: draft, template: template, scope: scope ?? self.scope, editing: key)
    }

    private func options(_ count: Int) -> String {
        (1...count).map { "Option \($0)" }.joined(separator: "\n")
    }

    @Test("Each way a name can be wrong is named")
    func nameIssues() {
        #expect(issue(Fixtures.draft("")) == .nameEmpty)
        #expect(issue(Fixtures.draft("   ")) == .nameEmpty)
        #expect(issue(Fixtures.draft(String(repeating: "a", count: 41))) == .nameTooLong)
        #expect(issue(Fixtures.draft(String(repeating: "a", count: 40))) == nil)
        #expect(RecordTemplateEditor.maximumNameLength == 40)
    }

    @Test("A pick-from-options field needs two to twelve different options, none too long")
    func optionIssues() {
        func choice(_ text: String) -> RecordFieldDraft { Fixtures.draft("Fine", kind: .choice, options: text) }

        #expect(issue(choice("")) == .tooFewOptions)
        #expect(issue(choice("Only one")) == .tooFewOptions)
        #expect(issue(choice("Same\nsame")) == .tooFewOptions)
        #expect(issue(choice("One\nTwo")) == nil)
        #expect(issue(choice(options(12))) == nil)
        #expect(issue(choice(options(13))) == .tooManyOptions)
        #expect(issue(choice("One\n" + String(repeating: "x", count: 40))) == nil)
        #expect(issue(choice("One\n" + String(repeating: "x", count: 41))) == .optionTooLong)
    }

    @Test("A unit may be twelve characters")
    func unitIssues() {
        let twelve = String(repeating: "u", count: 12)
        #expect(issue(Fixtures.draft("Fine", kind: .number, unit: twelve)) == nil)
        #expect(issue(Fixtures.draft("Fine", kind: .number, unit: twelve + "u")) == .unitTooLong)
    }

    @Test("Options and unit are only checked for the kinds that have them")
    func optionsOnlyMatterForChoices() {
        let noisy = Fixtures.draft("Fine", kind: .text, options: "x", unit: String(repeating: "u", count: 99))
        #expect(issue(noisy) == nil)
        #expect(issue(Fixtures.draft("Fine", kind: .yesNo, options: "x")) == nil)
    }

    @Test("A name may not repeat a catalog field or another field of hers, ignoring case and accents")
    func namesAreUniquePerProfession() {
        let template = Fixtures.makeTemplate(custom: [Fixtures.custom("Humeur", key: "custom-1")])
        let hair = RecordTemplateEditor.Scope(profession: .hair, reservedNames: ["Formula"])

        #expect(issue(Fixtures.draft("skin CONDITION"), in: template) == .nameTaken)
        #expect(issue(Fixtures.draft("technique"), in: template) == .nameTaken)
        #expect(issue(Fixtures.draft("HUMEUR"), in: template) == .nameTaken)
        #expect(issue(Fixtures.draft("humeur "), in: template) == .nameTaken)
        #expect(issue(Fixtures.draft("Mood"), in: template) == nil)
        // The same name is free in another profession.
        #expect(issue(Fixtures.draft("Humeur"), in: template, scope: hair) == nil)
        #expect(issue(Fixtures.draft("formula"), in: template, scope: hair) == .nameTaken)
    }

    @Test("A profession holds at most thirty fields of her own, and the limit only stops new ones")
    func limitsCustomFields() {
        let full = Fixtures.full(custom: 30)
        let hair = RecordTemplateEditor.Scope(profession: .hair, reservedNames: [])

        #expect(RecordTemplateEditor.maximumCustomFields == 30)
        #expect(issue(Fixtures.draft("One more"), in: full) == .limitReached)
        #expect(issue(Fixtures.draft("Renamed"), in: full, editing: "custom-5") == nil)
        // Another profession has its own thirty.
        #expect(issue(Fixtures.draft("Mine"), in: full, scope: hair) == nil)
        #expect(issue(Fixtures.draft("The thirtieth"), in: Fixtures.full(custom: 29)) == nil)
    }

    @Test("A full profession refuses another field")
    func fullProfessionRefuses() {
        let result = RecordTemplateEditor.adding(
            Fixtures.draft("One more"), to: Fixtures.full(custom: 30), scope: scope, makeID: UUID.init, now: later
        )
        #expect(result == .failure(.limitReached))
    }

    @Test("The issue says which part of the sheet it belongs to")
    func issueParts() {
        #expect(RecordFieldIssue.nameTaken.part == .name && RecordFieldIssue.nameEmpty.part == .name)
        #expect(RecordFieldIssue.tooFewOptions.part == .options && RecordFieldIssue.optionTooLong.part == .options)
        #expect(RecordFieldIssue.unitTooLong.part == .unit)
        #expect(RecordFieldIssue.limitReached.part == .general && RecordFieldIssue.notFound.part == .general)
    }
}
