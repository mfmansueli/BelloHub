//
//  RecordCorrectableField.swift
//  BelloHub
//

import Foundation

/// The text fields of a treatment record that a correction (or, before the lock, an edit) can change. The raw value is
/// the key stored in `RecordCorrection.fieldKey`, so it never changes with the language or a rename.
enum RecordCorrectableField: String, CaseIterable, Identifiable, Sendable {
    case notes
    case technique
    case resultDetail
    case aftercare
    case nextSessionSuggestion

    var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .notes: "record.field.notes"
        case .technique: "record.field.technique"
        case .resultDetail: "record.field.resultDetail"
        case .aftercare: "record.field.aftercare"
        case .nextSessionSuggestion: "record.field.nextSession"
        }
    }

    /// What the record says in this field, before any correction.
    func originalValue(in record: TreatmentRecord) -> String? {
        switch self {
        case .notes: record.notes
        case .technique: record.technique
        case .resultDetail: record.resultDetail
        case .aftercare: record.aftercare
        case .nextSessionSuggestion: record.nextSessionSuggestion
        }
    }

    func setting(_ value: String?, in record: TreatmentRecord) -> TreatmentRecord {
        var changed = record
        switch self {
        case .notes: changed.notes = value
        case .technique: changed.technique = value
        case .resultDetail: changed.resultDetail = value
        case .aftercare: changed.aftercare = value
        case .nextSessionSuggestion: changed.nextSessionSuggestion = value
        }
        return changed
    }
}
