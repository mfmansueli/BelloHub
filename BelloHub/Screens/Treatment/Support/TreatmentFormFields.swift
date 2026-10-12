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
    /// professions and asked for this visit's service. A catalog field the catalog no longer names is left out (there
    /// is nothing to call it); a field she added always has her own name.
    static func resolve(
        template: RecordTemplate?, professions: [ProfessionID], catalog: ProfessionCatalog, notesName: String,
        serviceID: UUID? = nil
    ) -> [TreatmentFormField] {
        var fields = [TreatmentFormField(key: TreatmentFormField.notesKey, name: notesName, input: .text, role: .notes)]
        var seenKeys: Set<String> = [TreatmentFormField.notesKey]
        var claimedRoles: Set<String> = []
        for profession in professions {
            for setting in template?.fields(for: profession) ?? []
            where setting.isOn && setting.applies(toService: serviceID) {
                guard seenKeys.insert(setting.key).inserted,
                      let name = name(of: setting, in: catalog) else { continue }
                var role = role(forKey: setting.key)
                if role != .generic, !claimedRoles.insert("\(role)").inserted { role = .generic }
                fields.append(TreatmentFormField(key: setting.key, name: name, input: input(of: setting, role: role),
                                                 role: role, isRequired: setting.isRequired))
            }
        }
        return fields
    }

    /// The form's fields plus the ones every visit offers: aftercare (when her template has none of its own), the
    /// client's reaction and what to remember next time. They are optional like every other field.
    static func withVisitFields(
        _ fields: [TreatmentFormField], aftercareName: String, reactionName: String, reminderName: String
    ) -> [TreatmentFormField] {
        var all = fields
        if !fields.contains(where: { $0.role == .aftercare }) {
            all.append(TreatmentFormField(key: TreatmentFormField.aftercareKey, name: aftercareName, input: .text,
                                          role: .aftercare))
        }
        all.append(TreatmentFormField(key: TreatmentFormField.reactionKey, name: reactionName, input: .text,
                                      role: .reaction))
        all.append(TreatmentFormField(key: TreatmentFormField.reminderKey, name: reminderName, input: .text,
                                      role: .nextVisitReminder))
        return all
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
