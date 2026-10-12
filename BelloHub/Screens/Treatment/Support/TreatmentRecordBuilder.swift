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
        /// The day the treatment happened, as she set it on the form.
        var performedAt: Date?
        /// A draft while she works; finalized when she says so.
        var status = RecordStatus.finalized
        /// The record as it was before this save (a draft being continued, a record being completed). What the form
        /// has no field for is carried over from it, so a field switched off since, or a part copied from an earlier
        /// visit, is never dropped by saving.
        var carried: TreatmentRecord?
    }

    enum Issue: Equatable, Sendable {
        /// She has not filled in anything: an empty record is not saved.
        case nothingToSave
        /// A number field holds something that is not a number.
        case invalidNumber(key: String)
        /// A field her template needs before finalizing is empty. It never stops a draft from being saved.
        case missingRequired(key: String)
    }

    /// The problems that stop finalizing, in the form's order. A draft is saved whatever they say.
    static func issues(of draft: TreatmentDraft, fields: [TreatmentFormField], locale: Locale) -> [Issue] {
        var found: [Issue] = []
        if draft.isEmpty { found.append(.nothingToSave) }
        for field in fields {
            let value = draft.value(for: field.key).trimmingCharacters(in: .whitespacesAndNewlines)
            if field.isRequired, value.isEmpty { found.append(.missingRequired(key: field.key)) }
            guard case .number = field.input else { continue }
            if PriceInput(value, locale: locale) == .invalid { found.append(.invalidNumber(key: field.key)) }
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
            performedAt: context.performedAt, status: context.status, source: context.source,
            result: draft.result ?? .neutral, aiAssisted: context.aiAssisted
        )
        carry(context.carried, into: &record, fields: fields)
        var entries: [RecordFieldEntry] = []
        for field in fields {
            let value = draft.value(for: field.key).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !value.isEmpty else { continue }
            if field.role == .generic {
                entries.append(entry(for: field, value: value, locale: locale))
            } else {
                place(value, of: field, draft: draft, into: &record)
            }
        }
        let suggestion = draft.value(for: TreatmentFormField.nextSessionKey)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !suggestion.isEmpty { record.nextSessionSuggestion = suggestion }
        // Answers of fields the form no longer shows (switched off since) stay with the record.
        let shown = Set(fields.map(\.key))
        entries += (context.carried?.fieldEntries ?? []).filter { !shown.contains($0.key) }
        record.fieldEntries = entries
        return record
    }

    /// Copies from the earlier version of the record what the form has no field for: a part with no field in her
    /// template now is kept as it was, never erased by a save.
    private static func carry(_ carried: TreatmentRecord?, into record: inout TreatmentRecord,
                              fields: [TreatmentFormField]) {
        guard let carried else { return }
        let roles = Set(fields.map { "\($0.role)" })
        func lacks(_ role: TreatmentFormField.Role) -> Bool { !roles.contains("\(role)") }
        if lacks(.notes) { record.notes = carried.notes }
        if lacks(.products) { record.productsUsed = carried.productsUsed }
        if lacks(.technique) { record.technique = carried.technique }
        if lacks(.result) { record.resultDetail = carried.resultDetail }
        if lacks(.aftercare) { record.aftercare = carried.aftercare }
        if lacks(.reaction) { record.reaction = carried.reaction }
        if lacks(.nextVisitReminder) { record.nextVisitReminder = carried.nextVisitReminder }
        record.nextSessionSuggestion = carried.nextSessionSuggestion
    }

    // MARK: - Private

    /// Puts one answer into the record's part that the field's role names. Generic fields are entries instead.
    private static func place(
        _ value: String, of field: TreatmentFormField, draft: TreatmentDraft, into record: inout TreatmentRecord
    ) {
        switch field.role {
        case .notes: record.notes = value
        case .products: record.productsUsed = draft.lines(for: field.key)
        case .technique: record.technique = value
        case .result: record.resultDetail = value
        case .aftercare: record.aftercare = value
        case .nextSession: record.nextSessionSuggestion = value
        case .reaction: record.reaction = value
        case .nextVisitReminder: record.nextVisitReminder = value
        case .generic: break
        }
    }

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
