//
//  RecordCurrentValues.swift
//  BelloHub
//

import Foundation

/// What a record says **now**: every field with its latest correction applied. The timeline card, the visit details,
/// "Before you start" and the export all read a record through this, so a corrected value never shows as the original
/// anywhere while the original stays untouched in the vault.
struct RecordCurrentValues: Sendable {
    /// The correction key of the visit day, stored as an ISO 8601 instant.
    static let performedAtKey = "performedAt"

    let record: TreatmentRecord
    let corrections: [RecordCorrection]

    init(record: TreatmentRecord, corrections: [RecordCorrection]) {
        self.record = record
        self.corrections = corrections.filter { $0.recordID == record.id }
    }

    func value(_ field: RecordCorrectableField) -> String? {
        RecordEditRules.currentValue(of: field, in: record, corrections: corrections)
    }

    func value(_ field: RecordEditableField) -> String? {
        RecordEditRules.currentValue(of: field, in: record, corrections: corrections)
    }

    var products: [String] {
        RecordCorrectableField.products(from: value(.productsUsed))
    }

    /// Her template answers as they read now, in the record's order, then any answer added by a correction after the
    /// lock (named from `templateFields`). Emptied answers are left out.
    func entries(templateFields: [RecordFieldEntry] = []) -> [RecordFieldEntry] {
        var result: [RecordFieldEntry] = []
        for entry in record.fieldEntries ?? [] {
            let field = RecordEditableField.entry(key: entry.key, name: entry.name, kind: entry.kind, unit: entry.unit)
            guard let current = value(field), !current.isEmpty else { continue }
            var updated = entry
            updated.value = current
            result.append(updated)
        }
        let known = Set((record.fieldEntries ?? []).map(\.key))
        for template in templateFields where !known.contains(template.key) {
            let field = RecordEditableField.entry(key: template.key, name: template.name, kind: template.kind,
                                                  unit: template.unit)
            guard let added = value(field), !added.isEmpty else { continue }
            var entry = template
            entry.value = added
            result.append(entry)
        }
        return result
    }

    /// The visit day as it reads now: a logged correction of the day wins over the stored one.
    var performedAt: Date? {
        let latest = corrections
            .filter { $0.fieldKey == Self.performedAtKey }
            .max { $0.createdAt < $1.createdAt }
        guard let latest else { return record.performedAt }
        return latest.newValue.flatMap(Self.date(from:))
    }

    /// The record with every correction applied, for code that reads a plain record (the visit day included).
    var applied: TreatmentRecord {
        var copy = record
        for field in RecordCorrectableField.allCases {
            copy = field.setting(value(field), in: copy)
        }
        copy.fieldEntries = record.fieldEntries == nil && entries().isEmpty ? nil : entries()
        copy.performedAt = performedAt
        return copy
    }

    func visitDate(appointments: [UUID: Appointment]) -> RecordVisitDate {
        var current = record
        current.performedAt = performedAt
        return RecordVisitDate.resolve(current, appointments: appointments)
    }

    /// The text a visit-day correction stores, and back.
    static func text(from date: Date) -> String {
        date.formatted(.iso8601)
    }

    static func date(from text: String) -> Date? {
        try? Date(text, strategy: .iso8601)
    }
}
