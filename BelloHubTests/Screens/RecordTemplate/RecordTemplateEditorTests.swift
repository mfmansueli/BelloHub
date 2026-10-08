//
//  RecordTemplateEditorTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

private typealias Fixtures = RecordTemplateFixtures

@Suite("RecordTemplateEditor: switches, options and adding")
struct RecordTemplateEditorTests {
    private let scope = Fixtures.scope
    private let later = Fixtures.later

    // MARK: - Switches

    @Test("A field is switched on and off, and nothing else changes")
    func switchesAField() {
        let template = Fixtures.makeTemplate()

        let on = RecordTemplateEditor.setting("est.technique", on: true, for: .esthetician, in: template, now: later)

        #expect(on.fields.map(\.isOn) == [true, true, true])
        #expect(on.updatedAt == later)
        #expect(on.intake == template.intake)
        let off = RecordTemplateEditor.setting("est.skin", on: false, for: .esthetician, in: on, now: later)
        #expect(off.enabledKeys(for: .esthetician) == ["est.technique"])
        #expect(off.enabledKeys(for: .hair) == ["hair.formula"])
    }

    @Test("Switching to the state a field is already in, or a key that does not exist, changes nothing")
    func switchingNothing() {
        let template = Fixtures.makeTemplate()
        func set(_ key: String, _ on: Bool, _ profession: ProfessionID) -> RecordTemplate {
            RecordTemplateEditor.setting(key, on: on, for: profession, in: template, now: later)
        }
        #expect(set("est.skin", true, .esthetician) == template)
        #expect(set("nope", true, .esthetician) == template)
        #expect(set("est.skin", false, .hair) == template)
    }

    @Test("An intake item is switched, and one the template never had gets an entry")
    func switchesIntake() {
        let template = Fixtures.makeTemplate()

        let off = RecordTemplateEditor.settingIntake(
            .consentForm, on: false, for: .esthetician, in: template, now: later
        )
        #expect(!off.isIntakeOn(.consentForm, for: .esthetician) && off.isIntakeOn(.healthHistory, for: .esthetician))

        let added = RecordTemplateEditor.settingIntake(.healthHistory, on: true, for: .hair, in: template, now: later)
        #expect(added.isIntakeOn(.healthHistory, for: .hair) && added.intake.count == 4)

        let same = RecordTemplateEditor.settingIntake(
            .healthHistory, on: true, for: .esthetician, in: template, now: later
        )
        #expect(same == template)
    }

    // MARK: - Options

    @Test("Options are one per line, cleaned, without blanks or repeats")
    func parsesOptions() {
        let text = "Matte\n  Dewy  \n\nmatte\nSATIN\r\nSátin\nGloss"
        #expect(RecordTemplateEditor.parseOptions(text) == ["Matte", "Dewy", "SATIN", "Gloss"])
        #expect(RecordTemplateEditor.parseOptions("Matte\nmatte\nMATTE") == ["Matte"])
        #expect(RecordTemplateEditor.parseOptions("café\nCAFE") == ["café"])
        #expect(RecordTemplateEditor.parseOptions("  \n \n").isEmpty)
        #expect(RecordTemplateEditor.parseOptions("").isEmpty)
    }

    // MARK: - Adding

    @Test("A new text field gets a stable custom key, starts on and goes after the profession's last field")
    func addsATextField() throws {
        let id = UUID()

        let updated = try Fixtures.adding(Fixtures.draft("  Mood   today "), to: Fixtures.makeTemplate(), id: id)

        let field = try #require(updated.fields.first { $0.isCustom })
        #expect(field.key == "custom-\(id.uuidString.lowercased())")
        #expect(field.customName == "Mood today" && field.isOn)
        #expect(field.kind == .text && field.options.isEmpty && field.unit == nil)
        #expect(Fixtures.keys(updated) == ["est.skin", "est.technique", field.key, "hair.formula"])
        #expect(updated.updatedAt == later)
    }

    @Test("A choice field keeps its cleaned options and drops a unit she typed before switching kind")
    func addsAChoiceField() throws {
        let draft = Fixtures.draft("Finish", kind: .choice, options: "Matte\n Dewy \nmatte", unit: "mm")

        let updated = try Fixtures.adding(draft, to: Fixtures.makeTemplate())

        let field = try #require(updated.fields.first { $0.isCustom })
        #expect(field.kind == .choice && field.options == ["Matte", "Dewy"] && field.unit == nil)
    }

    @Test("A number field keeps its cleaned unit, or none when it is blank, and drops options")
    func addsANumberField() throws {
        let template = Fixtures.makeTemplate()
        let length = Fixtures.draft("Length", kind: .number, options: "a\nb", unit: "  mm ")
        let withUnit = try Fixtures.adding(length, to: template)
        let bare = try Fixtures.adding(Fixtures.draft("Count", kind: .number, unit: "  "), to: template)

        #expect(withUnit.fields.first { $0.isCustom }?.unit == "mm")
        #expect(withUnit.fields.first { $0.isCustom }?.options == [])
        #expect(bare.fields.first { $0.isCustom }?.unit == nil)
    }

    @Test("A yes-or-no field needs nothing more than a name")
    func addsAYesNoField() throws {
        let updated = try Fixtures.adding(Fixtures.draft("Patch test done", kind: .yesNo), to: Fixtures.makeTemplate())
        #expect(updated.fields.first { $0.isCustom }?.kind == .yesNo)
    }

    @Test("A profession with no fields yet gets its first field at the end of the list")
    func addsToAnEmptyProfession() throws {
        let barber = RecordTemplateEditor.Scope(profession: .barber, reservedNames: [])

        let updated = try RecordTemplateEditor.adding(
            Fixtures.draft("Beard line"), to: Fixtures.makeTemplate(), scope: barber, makeID: UUID.init, now: later
        ).get()

        #expect(updated.fields.last?.profession == .barber && updated.fields.count == 4)
    }

    @Test("A draft that is not valid adds nothing")
    func invalidDraftAddsNothing() {
        let result = RecordTemplateEditor.adding(
            Fixtures.draft(""), to: Fixtures.makeTemplate(), scope: scope, makeID: UUID.init, now: later
        )
        #expect(result == .failure(.nameEmpty))
    }

    @Test("Two fields added with different ids get different keys")
    func keysAreUnique() throws {
        let first = try Fixtures.adding(Fixtures.draft("One"), to: Fixtures.makeTemplate())
        let second = try Fixtures.adding(Fixtures.draft("Two"), to: first)
        let keys = second.fields.filter(\.isCustom).map(\.key)
        #expect(Set(keys).count == 2 && keys.allSatisfy { $0.hasPrefix("custom-") })
    }
}
