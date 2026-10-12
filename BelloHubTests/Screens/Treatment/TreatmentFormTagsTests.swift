//
//  TreatmentFormTagsTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

/// Quick answers on the visit form: each field of her profession comes with the answers that profession writes, her
/// own answers take over once she saves one, and the fields every visit has gather her professions' reactions and
/// aftercare.
@Suite("Treatment form quick answers")
struct TreatmentFormTagsTests {
    private func catalog() throws -> ProfessionCatalog {
        let json = """
        {"localization": "en", "professions": [
          {"id": "esthetician", "name": "Esthetician", "plural": "estheticians", "services": [], "tags": [],
           "fields": [
             {"key": "esthetician.healthCheck", "name": "Health check today", "on": true,
              "tags": ["No changes", "Isotretinoin"]},
             {"key": "esthetician.skinCondition", "name": "Skin condition", "on": true, "tags": ["Oily", "Dry"]},
             {"key": "esthetician.products", "name": "Products and actives", "on": true, "tags": ["Retinol"]}],
           "intake": [], "reactionTags": ["None", "Mild redness"], "aftercareTags": ["SPF 50 daily"]},
          {"id": "lash", "name": "Lash artist", "plural": "lash artists", "services": [], "tags": [],
           "fields": [{"key": "lash.curl", "name": "Curl", "on": true, "tags": ["C", "D"]}],
           "intake": [], "reactionTags": ["None", "Watery eyes"], "aftercareTags": ["Keep dry 24 h"]}]}
        """
        return try ProfessionCatalog.decode(Data(json.utf8))
    }

    private func template(_ fields: [RecordFieldSetting]) -> RecordTemplate {
        RecordTemplate(fields: fields, intake: [], updatedAt: TestClock.now)
    }

    @Test("A written field offers her profession's answers until she saves her own")
    func catalogTags() throws {
        let saved = template([
            RecordFieldSetting(profession: .esthetician, key: "esthetician.healthCheck", isOn: true),
            RecordFieldSetting(profession: .esthetician, key: "esthetician.skinCondition", isOn: true,
                               options: ["Oily", "Dry", "Couperose"])
        ])

        let fields = TreatmentFormFields.resolve(
            template: saved, professions: [.esthetician], catalog: try catalog(), notesName: "Notes"
        )

        #expect(fields.first { $0.key == "esthetician.healthCheck" }?.tags == ["No changes", "Isotretinoin"])
        #expect(fields.first { $0.key == "esthetician.skinCondition" }?.tags == ["Oily", "Dry", "Couperose"])
        #expect(fields.first { $0.key == "notes" }?.tags.isEmpty == true)
    }

    @Test("A choice field keeps its choices as choices, and a number gets no answers")
    func otherKinds() throws {
        let saved = template([
            RecordFieldSetting(profession: .esthetician, key: "custom-1", customName: "Peel", isOn: true,
                               kind: .choice, options: ["Light", "Medium"]),
            RecordFieldSetting(profession: .esthetician, key: "custom-2", customName: "Minutes", isOn: true,
                               kind: .number)
        ])

        let fields = TreatmentFormFields.resolve(
            template: saved, professions: [.esthetician], catalog: try catalog(), notesName: "Notes"
        )

        #expect(fields.first { $0.key == "custom-1" }?.input == .choice(["Light", "Medium"]))
        #expect(fields.first { $0.key == "custom-1" }?.tags.isEmpty == true)
        #expect(fields.first { $0.key == "custom-2" }?.tags.isEmpty == true)
    }

    @Test("A field the catalog added after she saved her template reaches the form, in its catalog place")
    func newCatalogField() throws {
        let stale = template([
            RecordFieldSetting(profession: .esthetician, key: "esthetician.skinCondition", isOn: true)
        ])

        let keys = TreatmentFormFields.resolve(
            template: stale, professions: [.esthetician], catalog: try catalog(), notesName: "Notes"
        ).map(\.key)

        #expect(keys == ["notes", "esthetician.healthCheck", "esthetician.skinCondition", "esthetician.products"])
    }

    @Test("Products and actives offer the profession's names next to her product list")
    func productTags() throws {
        let fields = TreatmentFormFields.resolve(
            template: template([]), professions: [.esthetician], catalog: try catalog(), notesName: "Notes"
        )
        #expect(fields.first { $0.key == "esthetician.products" }?.tags == ["Retinol"])
    }

    @Test("Reaction and aftercare gather every profession's answers, each once, in her order")
    func visitTags() throws {
        let tags = TreatmentFormFields.visitTags(professions: [.lash, .esthetician], catalog: try catalog())
        #expect(tags.reaction == ["None", "Watery eyes", "Mild redness"])
        #expect(tags.aftercare == ["Keep dry 24 h", "SPF 50 daily"])

        let fields = TreatmentFormFields.withVisitFields(
            [], aftercareName: "Aftercare", reactionName: "Reaction", reminderName: "Next time", tags: tags
        )
        #expect(fields.first { $0.role == .reaction }?.tags == tags.reaction)
        #expect(fields.first { $0.role == .aftercare }?.tags == tags.aftercare)
        #expect(fields.first { $0.role == .nextVisitReminder }?.tags.isEmpty == true)
    }

    @Test("The same answer with other spaces or letter case is one answer")
    func unique() {
        let names = ["None", "none ", "Mild  redness", "Mild redness", ""]
        #expect(OptionNameRules.unique(names) == ["None", "Mild  redness"])
    }
}
