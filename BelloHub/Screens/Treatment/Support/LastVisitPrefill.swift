//
//  LastVisitPrefill.swift
//  BelloHub
//

import Foundation

/// "Same as last visit" on the manual form (routine-a item 8): her own answers from the client's latest record of the
/// same service, offered for the fields that are still empty. Only what tends to repeat (technique, products and her
/// template's own fields); never the observations, the result or the aftercare of another day. Nothing is filled in
/// until she taps it, and nothing is saved until she saves. Pure.
enum LastVisitPrefill {
    /// The latest record of this client for the same service (by id, else by name), other than the one being written.
    static func source(
        records: [TreatmentRecord], serviceID: UUID?, serviceName: String, excluding recordID: UUID
    ) -> TreatmentRecord? {
        let others = records.filter { $0.id != recordID }
        let sameService = others.filter { record in
            if let serviceID, let recordService = record.serviceID { return recordService == serviceID }
            return record.serviceName.caseInsensitiveCompare(serviceName) == .orderedSame
        }
        return sameService.max { $0.createdAt < $1.createdAt }
    }

    /// The answers to offer, by field key, for the fields of `fields` still empty in `draft`.
    static func values(
        from record: TreatmentRecord, fields: [TreatmentFormField], draft: TreatmentDraft
    ) -> [String: String] {
        var found: [String: String] = [:]
        let entries = Dictionary(
            (record.fieldEntries ?? []).map { ($0.key, $0.value) }, uniquingKeysWith: { first, _ in first }
        )
        for field in fields where draft.value(for: field.key).isEmpty {
            let value: String? = switch field.role {
            case .technique: record.technique
            case .products: record.productsUsed.isEmpty
                ? nil : record.productsUsed.joined(separator: RecordFieldEntry.optionSeparator)
            case .generic: entries[field.key]
            case .notes, .result, .aftercare, .nextSession: nil
            }
            if let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { found[field.key] = value }
        }
        return found
    }
}
