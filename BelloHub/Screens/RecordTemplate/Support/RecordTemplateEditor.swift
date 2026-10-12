//
//  RecordTemplateEditor.swift
//  BelloHub
//

import Foundation

/// Every change she can make to her record template (6.13), as pure functions from one `RecordTemplate` to the next.
/// The ViewModel only calls them and saves the result; the rules live here and nowhere else (CLAUDE.md section 2):
/// which names are accepted, how many fields of her own a profession can hold, how options are read, where a new
/// field goes, and how the template is topped up when the catalog has fields it does not yet know.
///
/// Nothing here deletes data a treatment record holds. The record keeps its own values keyed by the field's `key`;
/// switching a field off or deleting a custom one only changes what the form asks next time, and a `custom-<uuid>` key
/// is never reused for another field.
enum RecordTemplateEditor {
    static let maximumNameLength = 40
    /// Fields of her own, per profession.
    static let maximumCustomFields = 30
    static let minimumOptions = 2
    static let maximumOptions = 12
    static let maximumOptionLength = 40
    static let maximumUnitLength = 12

    /// Which profession a field belongs to, and the names of that profession's catalog fields (in the business
    /// language), which a field of hers may not repeat.
    struct Scope: Equatable, Sendable {
        let profession: ProfessionID
        let reservedNames: [String]
    }

    // MARK: - Reading

    /// The catalog's fields of a profession, in the order they are asked.
    static func standardFields(in template: RecordTemplate, for profession: ProfessionID) -> [RecordFieldSetting] {
        template.fields(for: profession).filter { !$0.isCustom }
    }

    /// The fields she added to a profession, in the order she arranged them.
    static func customFields(in template: RecordTemplate, for profession: ProfessionID) -> [RecordFieldSetting] {
        template.fields(for: profession).filter(\.isCustom)
    }

    // MARK: - Switches

    /// A field switched on or off. A key the template does not have changes nothing.
    static func setting(
        _ key: String, on: Bool, for profession: ProfessionID, in template: RecordTemplate, now: Date
    ) -> RecordTemplate {
        var updated = template
        guard let index = updated.fields.firstIndex(where: { $0.profession == profession && $0.key == key }),
              updated.fields[index].isOn != on else { return template }
        updated.fields[index].isOn = on
        updated.updatedAt = now
        return updated
    }

    /// A field marked as needed (or not) to finalize a record. Drafts never need it.
    static func settingRequired(
        _ key: String, required: Bool, for profession: ProfessionID, in template: RecordTemplate, now: Date
    ) -> RecordTemplate {
        updatingField(key, for: profession, in: template, now: now) { $0.isRequired = required }
    }

    /// The services a field is asked for; empty means every service. Duplicates are dropped, her order kept.
    static func settingServices(
        _ key: String, serviceIDs: [UUID], for profession: ProfessionID, in template: RecordTemplate, now: Date
    ) -> RecordTemplate {
        var seen: Set<UUID> = []
        let unique = serviceIDs.filter { seen.insert($0).inserted }
        return updatingField(key, for: profession, in: template, now: now) { $0.serviceIDs = unique }
    }

    private static func updatingField(
        _ key: String, for profession: ProfessionID, in template: RecordTemplate, now: Date,
        _ change: (inout RecordFieldSetting) -> Void
    ) -> RecordTemplate {
        guard let index = template.fields.firstIndex(where: { $0.profession == profession && $0.key == key })
        else { return template }
        var updated = template
        change(&updated.fields[index])
        guard updated.fields[index] != template.fields[index] else { return template }
        updated.updatedAt = now
        return updated
    }

    /// An intake item switched on or off. An item the template has no entry for yet gets one.
    static func settingIntake(
        _ item: IntakeItem, on: Bool, for profession: ProfessionID, in template: RecordTemplate, now: Date
    ) -> RecordTemplate {
        var updated = template
        if let index = updated.intake.firstIndex(where: { $0.profession == profession && $0.item == item }) {
            guard updated.intake[index].isOn != on else { return template }
            updated.intake[index].isOn = on
        } else {
            updated.intake.append(IntakeSetting(profession: profession, item: item, isOn: on))
        }
        updated.updatedAt = now
        return updated
    }

    // MARK: - Fields of her own

    /// The options she typed: one per line, whitespace collapsed, blank lines dropped and a repeat (ignoring case and
    /// accents) dropped, so "Matte" and "matte" are one option.
    static func parseOptions(_ text: String) -> [String] {
        var options: [String] = []
        var seen: Set<String> = []
        for line in text.split(whereSeparator: \.isNewline) {
            let option = OnboardingRules.cleaned(String(line))
            guard !option.isEmpty, seen.insert(OnboardingRules.comparisonKey(option)).inserted else { continue }
            options.append(option)
        }
        return options
    }

    /// The first thing wrong with `draft`, or nil when it can be saved. `key` is the field being edited: its own name
    /// does not count as taken, and the limit only applies to a new field.
    static func issue(
        in draft: RecordFieldDraft, template: RecordTemplate, scope: Scope, editing key: String? = nil
    ) -> RecordFieldIssue? {
        let custom = customFields(in: template, for: scope.profession)
        if key == nil, custom.count >= maximumCustomFields { return .limitReached }

        let name = OnboardingRules.cleaned(draft.name)
        if name.isEmpty { return .nameEmpty }
        if name.count > maximumNameLength { return .nameTooLong }
        let taken = scope.reservedNames + custom.filter { $0.key != key }.compactMap(\.customName)
        if OnboardingRules.acceptedName(name, existing: taken) == nil { return .nameTaken }

        if draft.kind.hasOptions {
            let options = draft.options
            if options.contains(where: { $0.count > maximumOptionLength }) { return .optionTooLong }
            if options.count > maximumOptions { return .tooManyOptions }
            if options.count < minimumOptions { return .tooFewOptions }
        }
        if draft.kind == .number, OnboardingRules.cleaned(draft.unit).count > maximumUnitLength { return .unitTooLong }
        return nil
    }

    /// The template with a new field of hers added, switched on, after the last field of the profession. The key is
    /// `custom-<uuid>`, built from `makeID`, and stays the same for the life of the field.
    static func adding(
        _ draft: RecordFieldDraft, to template: RecordTemplate, scope: Scope, makeID: () -> UUID, now: Date
    ) -> Result<RecordTemplate, RecordFieldIssue> {
        if let problem = issue(in: draft, template: template, scope: scope) { return .failure(problem) }
        let field = RecordFieldSetting(
            profession: scope.profession,
            key: RecordFieldSetting.customKeyPrefix + makeID().uuidString.lowercased(),
            customName: OnboardingRules.cleaned(draft.name),
            isOn: true,
            kind: draft.kind,
            options: draft.kind.hasOptions ? draft.options : [],
            unit: draft.kind == .number ? unit(of: draft) : nil
        )
        var updated = template
        let ofProfession = updated.fields.indices.filter { updated.fields[$0].profession == scope.profession }
        updated.fields.insert(field, at: (ofProfession.last ?? updated.fields.indices.last ?? -1) + 1)
        updated.updatedAt = now
        return .success(updated)
    }

    /// A field of hers renamed, with new options or a new unit. Its kind and key stay: changing how a field is filled
    /// would make what saved records hold for it mean something else.
    static func updating(
        _ key: String, with draft: RecordFieldDraft, in template: RecordTemplate, scope: Scope, now: Date
    ) -> Result<RecordTemplate, RecordFieldIssue> {
        guard let index = template.fields.firstIndex(where: {
            $0.profession == scope.profession && $0.key == key && $0.isCustom
        }) else { return .failure(.notFound) }
        var effective = draft
        effective.kind = template.fields[index].kind
        if let problem = issue(in: effective, template: template, scope: scope, editing: key) {
            return .failure(problem)
        }
        var updated = template
        updated.fields[index].customName = OnboardingRules.cleaned(draft.name)
        updated.fields[index].options = effective.kind.hasOptions ? effective.options : []
        updated.fields[index].unit = effective.kind == .number ? unit(of: effective) : nil
        updated.updatedAt = now
        return .success(updated)
    }

    /// The template without one of her fields. The catalog's fields cannot be removed, only switched off.
    static func removing(
        _ key: String, for profession: ProfessionID, from template: RecordTemplate, now: Date
    ) -> RecordTemplate {
        var updated = template
        updated.fields.removeAll { $0.profession == profession && $0.key == key && $0.isCustom }
        guard updated.fields.count != template.fields.count else { return template }
        updated.updatedAt = now
        return updated
    }

    /// Her own fields rearranged. `source` and `destination` follow `onMove` over the list `customFields` returns; the
    /// catalog's fields keep their place.
    static func movingCustomFields(
        from source: IndexSet, to destination: Int, for profession: ProfessionID, in template: RecordTemplate,
        now: Date
    ) -> RecordTemplate {
        let custom = customFields(in: template, for: profession)
        let rearranged = custom.movingElements(at: source, to: destination)
        guard rearranged != custom else { return template }
        var updated = template
        var next = rearranged.makeIterator()
        for index in updated.fields.indices where updated.fields[index].profession == profession
            && updated.fields[index].isCustom {
            if let field = next.next() { updated.fields[index] = field }
        }
        updated.updatedAt = now
        return updated
    }

    // MARK: - Completing

    /// The template completed with what the catalog added (`RecordTemplate.completed`, shared with the visit form).
    static func completed(
        _ template: RecordTemplate?, professions: [ProfessionID], catalog: ProfessionCatalog, now: Date
    ) -> RecordTemplate {
        RecordTemplate.completed(template, professions: professions, catalog: catalog, now: now)
    }

    // MARK: - Helpers

    /// The unit of a number field: cleaned, nil when she left it blank.
    private static func unit(of draft: RecordFieldDraft) -> String? {
        let cleaned = OnboardingRules.cleaned(draft.unit)
        return cleaned.isEmpty ? nil : cleaned
    }
}
