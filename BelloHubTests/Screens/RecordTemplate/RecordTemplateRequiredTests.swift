//
//  RecordTemplateRequiredTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

private typealias Fixtures = RecordTemplateFixtures

@Suite("Record fields needed to finalize, and fields per service")
struct RecordTemplateRequiredTests {
    private let later = Fixtures.later

    @Test("A field is marked as needed to finalize, and marking it again changes nothing")
    func markRequired() {
        let template = Fixtures.makeTemplate()
        let marked = RecordTemplateEditor.settingRequired("est.skin", required: true, for: .esthetician,
                                                          in: template, now: later)
        #expect(marked.fields.first { $0.key == "est.skin" }?.isRequired == true)
        #expect(marked.updatedAt == later)
        let again = RecordTemplateEditor.settingRequired("est.skin", required: true, for: .esthetician,
                                                         in: marked, now: TestClock.days(2))
        #expect(again == marked)
    }

    @Test("A field narrowed to services keeps her order without duplicates; empty means every service")
    func services() {
        let brow = UUID()
        let facial = UUID()
        let template = Fixtures.makeTemplate()
        let narrowed = RecordTemplateEditor.settingServices(
            "est.skin", serviceIDs: [brow, facial, brow], for: .esthetician, in: template, now: later
        )
        let field = narrowed.fields.first { $0.key == "est.skin" }
        #expect(field?.serviceIDs == [brow, facial])
        #expect(field?.applies(toService: brow) == true)
        #expect(field?.applies(toService: UUID()) == false)
        #expect(field?.applies(toService: nil) == true, "no service known yet: every field is asked")
        #expect(RecordFieldSetting(profession: .esthetician, key: "x", isOn: true).applies(toService: brow))
    }

    @Test("A field saved before these settings existed reads as optional and asked for every service")
    func oldFieldDecodes() throws {
        let json = #"{"profession":"esthetician","key":"est.skin","isOn":true}"#
        let field = try JSONDecoder().decode(RecordFieldSetting.self, from: Data(json.utf8))
        #expect(!field.isRequired)
        #expect(field.serviceIDs.isEmpty)
    }

    @Test("The form asks only the fields of the visit's service, marks the needed ones, and shows them unfolded")
    func formFields() {
        let brow = UUID()
        let template = RecordTemplate(
            fields: [
                RecordFieldSetting(profession: .esthetician, key: "custom-a", customName: "Shape", isOn: true,
                                   serviceIDs: [brow]),
                RecordFieldSetting(profession: .esthetician, key: "custom-b", customName: "Pressure", isOn: true,
                                   isRequired: true),
                RecordFieldSetting(profession: .esthetician, key: "custom-c", customName: "Mood", isOn: true),
                RecordFieldSetting(profession: .esthetician, key: "custom-d", customName: "Music", isOn: true)
            ],
            intake: [], updatedAt: TestClock.now
        )
        let catalog = ProfessionCatalog(localization: "en", status: "needs_review", entries: [])
        func keys(_ service: UUID?) -> [String] {
            TreatmentFormFields.resolve(template: template, professions: [.esthetician], catalog: catalog,
                                        notesName: "Notes", serviceID: service).map(\.key)
        }
        #expect(keys(brow) == ["notes", "custom-a", "custom-b", "custom-c", "custom-d"])
        #expect(keys(UUID()) == ["notes", "custom-b", "custom-c", "custom-d"])

        let fields = TreatmentFormFields.resolve(template: template, professions: [.esthetician], catalog: catalog,
                                                 notesName: "Notes", serviceID: UUID())
        #expect(fields.first { $0.key == "custom-b" }?.isRequired == true)
        // Mood and Music lead; Pressure is needed, so it never waits under "More fields".
        let layout = TreatmentFormLayout.split(fields, draft: TreatmentDraft())
        #expect(layout.more.isEmpty || !layout.more.contains { $0.key == "custom-b" })
    }

    @Test("A needed field stops finalizing only; it is reported once and clears when answered")
    func missingRequiredIssue() {
        let field = TreatmentFormField(key: "custom-b", name: "Pressure", input: .text, role: .generic,
                                       isRequired: true)
        let notes = TreatmentFormField(key: "notes", name: "Notes", input: .text, role: .notes)
        var draft = TreatmentDraft(values: ["notes": "Calm"])
        let locale = Locale(identifier: "en")
        #expect(TreatmentRecordBuilder.issues(of: draft, fields: [notes, field], locale: locale)
            == [.missingRequired(key: "custom-b")])
        draft.set("Light", for: "custom-b")
        #expect(TreatmentRecordBuilder.issues(of: draft, fields: [notes, field], locale: locale).isEmpty)
    }
}
