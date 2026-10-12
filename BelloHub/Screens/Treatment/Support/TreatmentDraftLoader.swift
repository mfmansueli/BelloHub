//
//  TreatmentDraftLoader.swift
//  BelloHub
//

import Foundation

/// The inverse of `TreatmentRecordBuilder`: a stored record back into the form's answers, so a draft is continued (or
/// an open record completed) exactly where she left it. Each field reads the record's part that its role names; her
/// template's own fields read their entry by key. Pure.
enum TreatmentDraftLoader {
    static func draft(from record: TreatmentRecord, fields: [TreatmentFormField]) -> TreatmentDraft {
        var draft = TreatmentDraft(result: record.isDraft && record.result == .neutral ? nil : record.result)
        let entries = Dictionary(
            (record.fieldEntries ?? []).map { ($0.key, $0.value) }, uniquingKeysWith: { first, _ in first }
        )
        for field in fields {
            if let value = value(for: field, in: record, entries: entries) { draft.set(value, for: field.key) }
        }
        if let suggestion = record.nextSessionSuggestion {
            draft.set(suggestion, for: TreatmentFormField.nextSessionKey)
        }
        return draft
    }

    /// The record's part that the field's role names; her template's own fields read their entry by key.
    private static func value(
        for field: TreatmentFormField, in record: TreatmentRecord, entries: [String: String]
    ) -> String? {
        switch field.role {
        case .notes: record.notes
        case .products: record.productsUsed.isEmpty
            ? nil : record.productsUsed.joined(separator: RecordFieldEntry.optionSeparator)
        case .technique: record.technique
        case .result: record.resultDetail
        case .aftercare: record.aftercare
        case .nextSession: record.nextSessionSuggestion
        case .reaction: record.reaction
        case .nextVisitReminder: record.nextVisitReminder
        case .generic: entries[field.key]
        }
    }
}
