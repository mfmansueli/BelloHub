//
//  RecordTrailBuilder.swift
//  BelloHub
//

import Foundation

/// Builds a record's change history: created, finalized (when a draft was finalized later), locked (once the 24 hours
/// have passed) and every correction, newest first.
/// The vault keeps no log of edits made before the lock, so the trail honestly starts with the creation.
enum RecordTrailBuilder {
    static func entries(for record: TreatmentRecord, corrections: [RecordCorrection], now: Date) -> [RecordTrailEntry] {
        var entries = [RecordTrailEntry(
            id: "created.\(record.id.uuidString)", date: record.createdAt,
            kind: .created(source: record.source, result: record.result, products: record.productsUsed)
        )]
        if let finalizedAt = record.finalizedAt, !record.isDraft, finalizedAt != record.createdAt {
            entries.append(RecordTrailEntry(
                id: "finalized.\(record.id.uuidString)", date: finalizedAt, kind: .finalized
            ))
        }
        if !record.isDraft, RecordLockPolicy.isLocked(lockedAt: record.lockedAt, now: now) {
            entries.append(RecordTrailEntry(id: "locked.\(record.id.uuidString)", date: record.lockedAt, kind: .locked))
        }
        for correction in corrections where correction.recordID == record.id {
            let entryName: String? = switch RecordEditableField.field(forKey: correction.fieldKey, in: record) {
            case .entry(_, let name, _, _): name
            default: nil
            }
            entries.append(RecordTrailEntry(
                id: "correction.\(correction.id.uuidString)", date: correction.createdAt,
                kind: .correction(correction, entryName: entryName)
            ))
        }
        return entries.sorted { lhs, rhs in
            lhs.date == rhs.date ? lhs.rank > rhs.rank : lhs.date > rhs.date
        }
    }
}
