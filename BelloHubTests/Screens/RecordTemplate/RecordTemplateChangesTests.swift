//
//  RecordTemplateChangesTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

private typealias Fixtures = RecordTemplateFixtures

/// Updating, removing and moving the fields of her own, and topping the template up from the catalog.
@Suite("RecordTemplateEditor: changes")
struct RecordTemplateChangesTests {
    private let scope = Fixtures.scope
    private let later = Fixtures.later

    private func update(
        _ key: String, _ draft: RecordFieldDraft, in template: RecordTemplate
    ) -> Result<RecordTemplate, RecordFieldIssue> {
        RecordTemplateEditor.updating(key, with: draft, in: template, scope: scope, now: later)
    }

    // MARK: - Updating

    @Test("Renaming keeps the key, the kind, the switch and the place")
    func renames() throws {
        let template = Fixtures.makeTemplate(custom: [Fixtures.custom("Mood", key: "custom-1")])

        let updated = try update("custom-1", Fixtures.draft(" Daily   mood "), in: template).get()

        let field = try #require(updated.fields.first { $0.key == "custom-1" })
        #expect(field.customName == "Daily mood" && field.isOn && field.kind == .text)
        #expect(Fixtures.keys(updated) == Fixtures.keys(template))
        #expect(updated.updatedAt == later)
    }

    @Test("A field can take a new case of its own name, and cannot take another field's name")
    func renamingAgainstItself() throws {
        let template = Fixtures.makeTemplate(custom: [
            Fixtures.custom("Mood", key: "custom-1"), Fixtures.custom("Energy", key: "custom-2")
        ])

        let recased = try update("custom-1", Fixtures.draft("MOOD"), in: template).get()

        #expect(recased.fields.first { $0.key == "custom-1" }?.customName == "MOOD")
        #expect(update("custom-1", Fixtures.draft("energy"), in: template) == .failure(.nameTaken))
        #expect(update("custom-1", Fixtures.draft("technique"), in: template) == .failure(.nameTaken))
    }

    @Test("The kind of a field cannot change once it exists, but its options and unit can")
    func kindIsLocked() throws {
        let finish = RecordFieldSetting(
            profession: .esthetician, key: "custom-1", customName: "Finish", isOn: true, kind: .choice,
            options: ["Matte", "Dewy"]
        )
        let length = RecordFieldSetting(
            profession: .esthetician, key: "custom-2", customName: "Length", isOn: true, kind: .number, unit: "mm"
        )
        let template = Fixtures.makeTemplate(custom: [finish, length])

        let first = try update(
            "custom-1", Fixtures.draft("Finish", kind: .number, options: "Matte\nDewy\nSatin"), in: template
        ).get()
        let second = try update("custom-2", Fixtures.draft("Length", kind: .text, unit: "cm"), in: first).get()

        #expect(second.fields.first { $0.key == "custom-1" }?.kind == .choice)
        #expect(second.fields.first { $0.key == "custom-1" }?.options == ["Matte", "Dewy", "Satin"])
        #expect(second.fields.first { $0.key == "custom-2" }?.kind == .number)
        #expect(second.fields.first { $0.key == "custom-2" }?.unit == "cm")
    }

    @Test("Editing a field that is gone, or one of the catalog's, fails")
    func updatingMissingFields() {
        let template = Fixtures.makeTemplate()
        #expect(update("custom-9", Fixtures.draft("X"), in: template) == .failure(.notFound))
        #expect(update("est.skin", Fixtures.draft("X"), in: template) == .failure(.notFound))
    }

    // MARK: - Removing and moving

    @Test("Only a field of hers can be removed; the catalog's fields can only be switched off")
    func removes() {
        let template = Fixtures.makeTemplate(custom: [Fixtures.custom("Mood", key: "custom-1")])

        let removed = RecordTemplateEditor.removing("custom-1", for: .esthetician, from: template, now: later)
        #expect(Fixtures.keys(removed) == ["est.skin", "est.technique", "hair.formula"] && removed.updatedAt == later)

        let standard = RecordTemplateEditor.removing("est.skin", for: .esthetician, from: template, now: later)
        let otherProfession = RecordTemplateEditor.removing("custom-1", for: .hair, from: template, now: later)
        let missing = RecordTemplateEditor.removing("custom-9", for: .esthetician, from: template, now: later)
        #expect(standard == template && otherProfession == template && missing == template)
    }

    @Test("Her fields move among themselves; the catalog's fields and the other professions stay where they are")
    func movesCustomFields() {
        let template = Fixtures.makeTemplate(custom: [
            Fixtures.custom("A", key: "custom-a"), Fixtures.custom("B", key: "custom-b"),
            Fixtures.custom("C", key: "custom-c")
        ])

        let moved = RecordTemplateEditor.movingCustomFields(
            from: [0], to: 3, for: .esthetician, in: template, now: later
        )

        #expect(Fixtures.keys(moved) == [
            "est.skin", "est.technique", "custom-b", "custom-c", "custom-a", "hair.formula"
        ])
        #expect(moved.updatedAt == later)
        let nowhere = RecordTemplateEditor.movingCustomFields(
            from: [1], to: 1, for: .esthetician, in: template, now: later
        )
        let otherProfession = RecordTemplateEditor.movingCustomFields(
            from: [0], to: 2, for: .hair, in: template, now: later
        )
        #expect(nowhere == template && otherProfession == template)
    }

    // MARK: - Completing

    @Test("A profession she has but never saved gets the catalog's fields and intake, as the catalog says")
    func completesAMissingProfession() {
        let template = Fixtures.makeTemplate()

        let completed = RecordTemplateEditor.completed(
            template, professions: [.esthetician, .other], catalog: makeCatalog(), now: later
        )

        #expect(completed.fields(for: .other).map(\.key) == ["other.notes"])
        #expect(completed.fields(for: .other).map(\.isOn) == [true])
        #expect(IntakeItem.allCases.allSatisfy { item in
            completed.intake.contains { $0.profession == .other && $0.item == item && !$0.isOn }
        })
        // What was there is untouched, and the timestamp is not bumped: this is not a write.
        #expect(completed.fields(for: .esthetician) == template.fields(for: .esthetician))
        #expect(completed.updatedAt == template.updatedAt)
    }

    @Test("A catalog field the template has never seen is added after the profession's catalog fields")
    func completesANewCatalogField() {
        let stale = RecordTemplate(
            fields: [
                RecordFieldSetting(profession: .esthetician, key: "est.skin", isOn: false),
                RecordFieldSetting(profession: .esthetician, key: "custom-1", customName: "Mood", isOn: true)
            ],
            intake: [], updatedAt: Fixtures.now
        )

        let completed = RecordTemplateEditor.completed(
            stale, professions: [.esthetician], catalog: makeCatalog(), now: later
        )

        #expect(Fixtures.keys(completed) == ["est.skin", "est.technique", "custom-1"])
        #expect(completed.fields[0].isOn == false, "a field that is there keeps her choice")
        #expect(completed.fields[1].isOn == false, "the new field starts as the catalog says")
    }

    @Test("Completing a template that is complete changes nothing, and a missing one starts from the catalog")
    func completingIsIdempotent() {
        let catalog = makeCatalog()
        let professions: [ProfessionID] = [.esthetician, .hair]
        let once = RecordTemplateEditor.completed(nil, professions: professions, catalog: catalog, now: Fixtures.now)
        let twice = RecordTemplateEditor.completed(once, professions: professions, catalog: catalog, now: later)

        #expect(once == twice)
        #expect(once.enabledKeys(for: .esthetician) == ["est.skin"])
        #expect(once.isIntakeOn(.healthHistory, for: .esthetician) && once.isIntakeOn(.patchTestLog, for: .hair))
        #expect(!once.isIntakeOn(.patchTestLog, for: .esthetician))
    }

    @Test("A profession the catalog does not know is left alone")
    func unknownProfessionIsSkipped() {
        let template = Fixtures.makeTemplate()
        let completed = RecordTemplateEditor.completed(
            template, professions: [.tattoo], catalog: makeCatalog(), now: later
        )
        #expect(completed == template)
    }
}
