//
//  RecordTemplateFixtures.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation

/// Shared by the record-template suites. A namespace, so the names cannot clash with another suite's factories.
enum RecordTemplateFixtures {
    static let now = TestClock.now
    static let later = TestClock.days(1)
    static let scope = RecordTemplateEditor.Scope(
        profession: .esthetician, reservedNames: ["Skin condition", "Technique"]
    )

    /// An esthetician with the two catalog fields (`est.skin` on, `est.technique` off) and a hair stylist with one,
    /// as onboarding would have saved them, with `custom` fields of hers after the esthetician's own.
    static func makeTemplate(custom: [RecordFieldSetting] = []) -> RecordTemplate {
        RecordTemplate(
            fields: [
                RecordFieldSetting(profession: .esthetician, key: "est.skin", isOn: true),
                RecordFieldSetting(profession: .esthetician, key: "est.technique", isOn: false)
            ] + custom + [RecordFieldSetting(profession: .hair, key: "hair.formula", isOn: true)],
            intake: [
                IntakeSetting(profession: .esthetician, item: .healthHistory, isOn: true),
                IntakeSetting(profession: .esthetician, item: .consentForm, isOn: true),
                IntakeSetting(profession: .esthetician, item: .patchTestLog, isOn: false)
            ],
            updatedAt: now
        )
    }

    static func draft(
        _ name: String, kind: RecordFieldKind = .text, options: String = "", unit: String = ""
    ) -> RecordFieldDraft {
        var draft = RecordFieldDraft()
        draft.name = name
        draft.kind = kind
        draft.optionsText = options
        draft.unit = unit
        return draft
    }

    /// A field of hers on the esthetician.
    static func custom(_ name: String, key: String, kind: RecordFieldKind = .text) -> RecordFieldSetting {
        RecordFieldSetting(profession: .esthetician, key: key, customName: name, isOn: true, kind: kind)
    }

    /// A template whose esthetician has `count` fields of her own.
    static func full(custom count: Int) -> RecordTemplate {
        makeTemplate(custom: (1...count).map { custom("Field \($0)", key: "custom-\($0)") })
    }

    /// Adds a field to `template` as the esthetician, failing the test with the issue if it is refused.
    static func adding(
        _ draft: RecordFieldDraft, to template: RecordTemplate, id: UUID = UUID()
    ) throws -> RecordTemplate {
        try RecordTemplateEditor.adding(draft, to: template, scope: scope, makeID: { id }, now: later).get()
    }

    static func keys(_ template: RecordTemplate) -> [String] {
        template.fields.map(\.key)
    }
}
