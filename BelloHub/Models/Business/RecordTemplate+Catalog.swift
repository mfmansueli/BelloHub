//
//  RecordTemplate+Catalog.swift
//  BelloHub
//

import Foundation

extension RecordTemplate {
    /// The template with what the catalog has and the template does not: the fields and intake items of a profession
    /// she has but never saved (a profession added after the setup), and catalog fields added in a newer version. They
    /// start as the catalog says, each in its catalog place (just before the next catalog field she already has, or
    /// after her last catalog field), so a new "Health check today" leads where the catalog puts it. It is a view of
    /// what to show, not a write: a screen saves only when she changes something, and a field that is already there is
    /// never changed. Used by the record template screen and by the visit form, so both show the same fields.
    static func completed(
        _ template: RecordTemplate?, professions: [ProfessionID], catalog: ProfessionCatalog, now: Date
    ) -> RecordTemplate {
        var result = template ?? RecordTemplate(fields: [], intake: [], updatedAt: now)
        for profession in professions {
            guard let entry = catalog.entry(for: profession) else { continue }
            result.insertMissingFields(of: entry, for: profession)
            for item in IntakeItem.allCases
            where !result.intake.contains(where: { $0.profession == profession && $0.item == item }) {
                let isOn = entry.intake.contains(item)
                result.intake.append(IntakeSetting(profession: profession, item: item, isOn: isOn))
            }
        }
        return result
    }

    private mutating func insertMissingFields(of entry: ProfessionEntry, for profession: ProfessionID) {
        let catalogKeys = entry.fields.map(\.key)
        for (index, suggested) in entry.fields.enumerated()
        where !fields.contains(where: { $0.profession == profession && $0.key == suggested.key }) {
            let setting = RecordFieldSetting(profession: profession, key: suggested.key, isOn: suggested.on)
            let later = Set(catalogKeys[(index + 1)...])
            let ofProfession = fields.indices.filter { fields[$0].profession == profession }
            if let next = ofProfession.first(where: { later.contains(fields[$0].key) }) {
                fields.insert(setting, at: next)
            } else {
                let lastStandard = ofProfession.last { !fields[$0].isCustom }
                let position = lastStandard.map { $0 + 1 } ?? ofProfession.first ?? fields.count
                fields.insert(setting, at: position)
            }
        }
    }
}
