//
//  RecordCorrectableField.swift
//  BelloHub
//

import Foundation

/// The fields of a treatment record that have a place of their own and that a correction (or, before the lock, an
/// edit) can change. The raw value is the key stored in `RecordCorrection.fieldKey`, so it never changes with the
/// language or a rename. The template's own fields are corrected through `RecordEditableField.entry`.
enum RecordCorrectableField: String, CaseIterable, Identifiable, Sendable {
    case notes
    case technique
    case productsUsed
    case resultDetail
    case reaction
    case aftercare
    case nextSessionSuggestion
    case nextVisitReminder

    var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .notes: "record.field.notes"
        case .technique: "record.field.technique"
        case .productsUsed: "record.field.products"
        case .resultDetail: "record.field.resultDetail"
        case .reaction: "record.field.reaction"
        case .aftercare: "record.field.aftercare"
        case .nextSessionSuggestion: "record.field.nextSession"
        case .nextVisitReminder: "record.field.nextVisitReminder"
        }
    }

    /// What the record says in this field, before any correction. Products read one per line, the way a correction
    /// stores them.
    func originalValue(in record: TreatmentRecord) -> String? {
        switch self {
        case .notes: record.notes
        case .technique: record.technique
        case .productsUsed: record.productsUsed.isEmpty ? nil : record.productsUsed.joined(separator: "\n")
        case .resultDetail: record.resultDetail
        case .reaction: record.reaction
        case .aftercare: record.aftercare
        case .nextSessionSuggestion: record.nextSessionSuggestion
        case .nextVisitReminder: record.nextVisitReminder
        }
    }

    func setting(_ value: String?, in record: TreatmentRecord) -> TreatmentRecord {
        var changed = record
        switch self {
        case .notes: changed.notes = value
        case .technique: changed.technique = value
        case .productsUsed: changed.productsUsed = Self.products(from: value)
        case .resultDetail: changed.resultDetail = value
        case .reaction: changed.reaction = value
        case .aftercare: changed.aftercare = value
        case .nextSessionSuggestion: changed.nextSessionSuggestion = value
        case .nextVisitReminder: changed.nextVisitReminder = value
        }
        return changed
    }

    /// One product per line, trimmed, without empty lines.
    static func products(from value: String?) -> [String] {
        (value ?? "")
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }
}
