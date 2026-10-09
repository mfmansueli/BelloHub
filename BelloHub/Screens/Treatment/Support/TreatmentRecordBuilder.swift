//
//  TreatmentRecordBuilder.swift
//  BelloHub
//

import Foundation

/// Turns the form's answers into a `TreatmentRecord`, and says what is wrong first. The one owner of "which answer
/// lives where": the record's own properties take the answers of the fields with a role, and every other field goes
/// into `fieldEntries` under its key, with the name and unit it has today.
enum TreatmentRecordBuilder {
    /// Who and what the record is about.
    struct Context: Equatable, Sendable {
        var clientID: UUID
        var appointmentID: UUID?
        var serviceID: UUID?
        var serviceName: String
        /// Fixed when the flow starts, so a retry updates the same record.
        var id = UUID()
        var createdAt = Date()
        var source = RecordSource.manual
        /// Set only after she reviewed every proposed field.
        var aiAssisted = false
    }

    enum Issue: Equatable, Sendable {
        /// She has not filled in anything: an empty record is not saved.
        case nothingToSave
        /// A number field holds something that is not a number.
        case invalidNumber(key: String)
    }

    /// The problems that stop a save, in the form's order.
    static func issues(of draft: TreatmentDraft, fields: [TreatmentFormField], locale: Locale) -> [Issue] {
        var found: [Issue] = []
        if draft.isEmpty { found.append(.nothingToSave) }
        for field in fields {
            guard case .number = field.input else { continue }
            if PriceInput(draft.value(for: field.key), locale: locale) == .invalid {
                found.append(.invalidNumber(key: field.key))
            }
        }
        return found
    }

    /// The record to save. The recommendation for the next visit is in the draft under `nextSessionKey`.
    static func build(
        draft: TreatmentDraft, fields: [TreatmentFormField], context: Context, locale: Locale
    ) -> TreatmentRecord {
        var record = TreatmentRecord(
            id: context.id, clientID: context.clientID, appointmentID: context.appointmentID,
            serviceID: context.serviceID, serviceName: context.serviceName, createdAt: context.createdAt,
            source: context.source, result: draft.result ?? .neutral, aiAssisted: context.aiAssisted
        )
        var entries: [RecordFieldEntry] = []
        for field in fields {
            let value = draft.value(for: field.key).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !value.isEmpty else { continue }
            switch field.role {
            case .notes: record.notes = value
            case .products: record.productsUsed = draft.lines(for: field.key)
            case .technique: record.technique = value
            case .result: record.resultDetail = value
            case .aftercare: record.aftercare = value
            case .nextSession: record.nextSessionSuggestion = value
            case .generic: entries.append(entry(for: field, value: value, locale: locale))
            }
        }
        let suggestion = draft.value(for: TreatmentFormField.nextSessionKey)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !suggestion.isEmpty { record.nextSessionSuggestion = suggestion }
        record.fieldEntries = entries
        return record
    }

    // MARK: - Private

    private static func entry(for field: TreatmentFormField, value: String, locale: Locale) -> RecordFieldEntry {
        var stored = value
        var kind = RecordFieldKind.text
        var unit: String?
        switch field.input {
        case .number(let fieldUnit):
            kind = .number
            unit = fieldUnit
            if case .value(let number) = PriceInput(value, locale: locale) { stored = "\(number)" }
        case .multiChoice: kind = .multiChoice
        case .choice: kind = .choice
        case .yesNo: kind = .yesNo
        case .text, .products: break
        }
        return RecordFieldEntry(key: field.key, name: field.name, kind: kind, value: stored, unit: unit)
    }
}
