//
//  TreatmentFormFields.swift
//  BelloHub
//

import Foundation

/// Which questions the treatment form asks: the fields she switched on for her professions (the template), in the
/// template's order, preceded by the observations every record has. Pure, so the choice of fields is tested without
/// a screen.
enum TreatmentFormFields {
    /// The record's own property a catalog field feeds, by the last part of its key (`esthetician.technique`).
    /// A custom field (`custom-<uuid>`) is always generic.
    static func role(forKey key: String) -> TreatmentFormField.Role {
        guard !key.hasPrefix(RecordFieldSetting.customKeyPrefix),
              let suffix = key.split(separator: ".").last.map(String.init) else { return .generic }
        switch suffix {
        case "products", "oils", "pigments": return .products
        case "technique": return .technique
        case "result": return .result
        case "aftercare", "homeCare": return .aftercare
        default: return .generic
        }
    }

    /// The form's fields: observations first, then every field of the template that is on for one of her
    /// professions and asked for this visit's service, with its quick answers. A catalog field the catalog no longer
    /// names is left out (there is nothing to call it); a field she added always has her own name. Fields the catalog
    /// added in a newer version join her template as the catalog sets them (`RecordTemplate.completed`), so a new
    /// field reaches a template she saved before it existed.
    static func resolve(
        template: RecordTemplate?, professions: [ProfessionID], catalog: ProfessionCatalog, notesName: String,
        serviceID: UUID? = nil, existingServiceIDs: Set<UUID>? = nil
    ) -> [TreatmentFormField] {
        var fields = [TreatmentFormField(key: TreatmentFormField.notesKey, name: notesName, input: .text, role: .notes)]
        var seenKeys: Set<String> = [TreatmentFormField.notesKey]
        var claimedRoles: Set<String> = []
        let completed = template.map {
            RecordTemplate.completed($0, professions: professions, catalog: catalog, now: $0.updatedAt)
        }
        for profession in professions {
            for setting in completed?.fields(for: profession) ?? []
            where setting.isOn && setting.applies(toService: serviceID, existing: existingServiceIDs) {
                guard seenKeys.insert(setting.key).inserted,
                      let name = name(of: setting, in: catalog) else { continue }
                var role = role(forKey: setting.key)
                if role != .generic, !claimedRoles.insert("\(role)").inserted { role = .generic }
                var field = TreatmentFormField(key: setting.key, name: name, input: input(of: setting, role: role),
                                               role: role, isRequired: setting.isRequired)
                field.tags = tags(of: setting, in: catalog)
                fields.append(field)
            }
        }
        return fields
    }

    /// The form's fields plus the ones every visit offers: aftercare (when her template has none of its own), the
    /// client's reaction and what to remember next time. They are optional like every other field. The reaction and
    /// the aftercare come with her professions' quick answers (`visitTags`).
    static func withVisitFields(
        _ fields: [TreatmentFormField], aftercareName: String, reactionName: String, reminderName: String,
        tags: VisitTags = VisitTags()
    ) -> [TreatmentFormField] {
        var all = fields
        if !fields.contains(where: { $0.role == .aftercare }) {
            var aftercare = TreatmentFormField(key: TreatmentFormField.aftercareKey, name: aftercareName, input: .text,
                                               role: .aftercare)
            aftercare.tags = tags.aftercare
            all.append(aftercare)
        }
        var reaction = TreatmentFormField(key: TreatmentFormField.reactionKey, name: reactionName, input: .text,
                                          role: .reaction)
        reaction.tags = tags.reaction
        all.append(reaction)
        all.append(TreatmentFormField(key: TreatmentFormField.reminderKey, name: reminderName, input: .text,
                                      role: .nextVisitReminder))
        return all
    }

    /// Quick answers of the fields every visit has, gathered over her professions in her order, each once.
    struct VisitTags: Equatable, Sendable {
        var reaction: [String] = []
        var aftercare: [String] = []
    }

    /// The reaction and aftercare answers of her professions: a lash artist who also does brows gets both lists, with
    /// a word they share ("None") once.
    static func visitTags(professions: [ProfessionID], catalog: ProfessionCatalog) -> VisitTags {
        let entries = professions.compactMap(catalog.entry(for:))
        return VisitTags(
            reaction: OptionNameRules.unique(entries.flatMap(\.reactionTags)),
            aftercare: OptionNameRules.unique(entries.flatMap(\.aftercareTags))
        )
    }

    /// The form's fields plus the recommendation for the next visit, which only the voice path proposes (the manual
    /// path sets the next visit in its own step).
    static func withRecommendation(_ fields: [TreatmentFormField], name: String) -> [TreatmentFormField] {
        fields + [TreatmentFormField(key: TreatmentFormField.nextSessionKey, name: name, input: .text,
                                     role: .nextSession)]
    }

    /// Her template's own fields (the ones with no place of their own on the record) as empty answers, so a visit's
    /// details can offer to complete a field the visit left blank.
    static func emptyEntries(_ fields: [TreatmentFormField]) -> [RecordFieldEntry] {
        fields.filter { $0.role == .generic }.map { field in
            let unit: String? = if case .number(let unit) = field.input { unit } else { nil }
            return RecordFieldEntry(key: field.key, name: field.name, kind: field.structuringKind, value: "",
                                    unit: unit)
        }
    }

    /// What the structuring technology may fill.
    static func structuringFields(from fields: [TreatmentFormField]) -> [StructuringField] {
        fields.map { StructuringField(key: $0.key, name: $0.name, kind: $0.structuringKind) }
    }

    // MARK: - Private

    /// A written field offers her template's own answers once she has added one, and her profession's until then.
    /// A choice field's options are its choices, and a number is typed, so neither gets tags.
    private static func tags(of setting: RecordFieldSetting, in catalog: ProfessionCatalog) -> [String] {
        guard setting.kind == .text else { return [] }
        guard setting.options.isEmpty else { return setting.options }
        return catalog.entry(for: setting.profession)?.fields.first { $0.key == setting.key }?.tags ?? []
    }

    private static func name(of setting: RecordFieldSetting, in catalog: ProfessionCatalog) -> String? {
        if let custom = setting.customName { return custom }
        return catalog.entry(for: setting.profession)?.fields.first { $0.key == setting.key }?.name
    }

    private static func input(
        of setting: RecordFieldSetting, role: TreatmentFormField.Role
    ) -> TreatmentFormField.Input {
        if role == .products { return .products }
        switch setting.kind {
        case .text: return .text
        case .number: return .number(unit: setting.unit)
        case .yesNo: return .yesNo
        case .choice: return setting.options.isEmpty ? .text : .choice(setting.options)
        case .multiChoice: return setting.options.isEmpty ? .text : .multiChoice(setting.options)
        }
    }
}
