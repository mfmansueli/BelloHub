//
//  RecordEditRules.swift
//  BelloHub
//

import Foundation

/// How a record's text changes: directly while it is open, and only by a logged correction once it is locked
/// (`RecordLockPolicy`, docs/01-PRODUCT.md rule 3). One owner for the rule; the ViewModel and the screen only ask.
enum RecordEditRules {
    enum Problem: Equatable {
        /// The new text is the same as what the record says now.
        case unchanged
        /// A locked record needs a reason for the log.
        case reasonMissing
    }

    /// What the record says in `field` now: the latest correction of that field, else the original.
    static func currentValue(
        of field: RecordEditableField, in record: TreatmentRecord, corrections: [RecordCorrection]
    ) -> String? {
        let latest = corrections
            .filter { $0.recordID == record.id && $0.fieldKey == field.fieldKey }
            .max { $0.createdAt < $1.createdAt }
        guard let latest else { return field.originalValue(in: record) }
        return latest.newValue
    }

    static func currentValue(
        of field: RecordCorrectableField, in record: TreatmentRecord, corrections: [RecordCorrection]
    ) -> String? {
        currentValue(of: .standard(field), in: record, corrections: corrections)
    }

    static func path(for record: TreatmentRecord, now: Date) -> RecordLockPolicy.EditPath {
        RecordLockPolicy.editPath(lockedAt: record.lockedAt, now: now)
    }

    /// Nil when the change can be saved.
    static func problem(
        for draft: RecordCorrectionDraft, record: TreatmentRecord, corrections: [RecordCorrection], now: Date
    ) -> Problem? {
        let current = currentValue(of: draft.field, in: record, corrections: corrections)
        if normalized(draft.newValue) == normalized(current) { return .unchanged }
        if path(for: record, now: now) == .addCorrection, normalized(draft.reason) == nil { return .reasonMissing }
        return nil
    }

    /// The correction to log. It keeps what the field said, what it says now and why, and never the whole record.
    static func correction(
        id: UUID, draft: RecordCorrectionDraft, record: TreatmentRecord, corrections: [RecordCorrection], now: Date
    ) -> RecordCorrection {
        RecordCorrection(
            id: id, recordID: record.id, createdAt: now, fieldKey: draft.field.fieldKey,
            oldValue: currentValue(of: draft.field, in: record, corrections: corrections),
            newValue: normalized(draft.newValue), reason: normalized(draft.reason)
        )
    }

    /// Trimmed text, or nil when nothing is left, which is how an emptied field is stored.
    static func normalized(_ text: String?) -> String? {
        guard let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else { return nil }
        return trimmed
    }
}
