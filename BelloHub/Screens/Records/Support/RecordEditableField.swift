//
//  RecordEditableField.swift
//  BelloHub
//

import Foundation

/// Any field of a record she can complete or correct: one with a place of its own (`RecordCorrectableField`) or one
/// of her template's fields (`RecordFieldEntry`). `fieldKey` is what a `RecordCorrection` stores; a template field is
/// stored as `field.<key>`, so its corrections survive a rename of the field.
enum RecordEditableField: Hashable, Identifiable, Sendable {
    case standard(RecordCorrectableField)
    /// A template field, with the name and kind it had on this record (or in the template, when it was empty).
    case entry(key: String, name: String, kind: RecordFieldKind, unit: String?)

    static let entryPrefix = "field."

    var fieldKey: String {
        switch self {
        case .standard(let field): field.rawValue
        case .entry(let key, _, _, _): Self.entryPrefix + key
        }
    }

    var id: String { fieldKey }

    func title(in locale: Locale) -> String {
        switch self {
        case .standard(let field): field.title.resolved(in: locale)
        case .entry(_, let name, _, _): name
        }
    }

    /// What the record says in this field, before any correction.
    func originalValue(in record: TreatmentRecord) -> String? {
        switch self {
        case .standard(let field):
            return field.originalValue(in: record)
        case .entry(let key, _, _, _):
            let value = record.fieldEntries?.first { $0.key == key }?.value
            return value?.isEmpty == true ? nil : value
        }
    }

    /// The record with this field set to `value`, for an open record or a draft (a locked one gets a correction).
    /// An emptied template field is removed, so the record never carries an empty answer.
    func setting(_ value: String?, in record: TreatmentRecord) -> TreatmentRecord {
        switch self {
        case .standard(let field):
            return field.setting(value, in: record)
        case .entry(let key, let name, let kind, let unit):
            var changed = record
            var entries = record.fieldEntries ?? []
            entries.removeAll { $0.key == key }
            if let value {
                let entry = RecordFieldEntry(key: key, name: name, kind: kind, value: value, unit: unit)
                if let index = record.fieldEntries?.firstIndex(where: { $0.key == key }) {
                    entries.insert(entry, at: min(index, entries.count))
                } else {
                    entries.append(entry)
                }
            }
            changed.fieldEntries = entries
            return changed
        }
    }

    /// Every field she can complete or correct on `record`: the ones with a place of their own, then the template
    /// fields the record already answers, then the template fields still empty (`templateFields`, in template order).
    static func all(for record: TreatmentRecord, templateFields: [RecordFieldEntry] = []) -> [RecordEditableField] {
        var fields = RecordCorrectableField.allCases.map(RecordEditableField.standard)
        let answered = record.fieldEntries ?? []
        fields += answered.map { .entry(key: $0.key, name: $0.name, kind: $0.kind, unit: $0.unit) }
        let answeredKeys = Set(answered.map(\.key))
        fields += templateFields
            .filter { !answeredKeys.contains($0.key) }
            .map { .entry(key: $0.key, name: $0.name, kind: $0.kind, unit: $0.unit) }
        return fields
    }

    /// The field a stored correction is about, resolved against the record (and the template for a field the record
    /// did not answer). Nil for a key this version does not know.
    static func field(
        forKey key: String, in record: TreatmentRecord, templateFields: [RecordFieldEntry] = []
    ) -> RecordEditableField? {
        if let standard = RecordCorrectableField(rawValue: key) { return .standard(standard) }
        guard key.hasPrefix(entryPrefix) else { return nil }
        let entryKey = String(key.dropFirst(entryPrefix.count))
        let entry = (record.fieldEntries ?? []).first { $0.key == entryKey }
            ?? templateFields.first { $0.key == entryKey }
        guard let entry else { return nil }
        return .entry(key: entry.key, name: entry.name, kind: entry.kind, unit: entry.unit)
    }
}
