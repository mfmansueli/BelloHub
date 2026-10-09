//
//  RecordTrailBuilder.swift
//  BelloHub
//

import Foundation

/// Builds a record's edit trail: created, locked (once the 24 hours have passed) and every correction, newest first.
/// The vault keeps no log of edits made before the lock, so the trail honestly starts with the creation.
enum RecordTrailBuilder {
    static func entries(for record: TreatmentRecord, corrections: [RecordCorrection], now: Date) -> [RecordTrailEntry] {
        var entries = [RecordTrailEntry(
            id: "created.\(record.id.uuidString)", date: record.createdAt,
            kind: .created(source: record.source, result: record.result, products: record.productsUsed)
        )]
        if RecordLockPolicy.isLocked(lockedAt: record.lockedAt, now: now) {
            entries.append(RecordTrailEntry(id: "locked.\(record.id.uuidString)", date: record.lockedAt, kind: .locked))
        }
        for correction in corrections where correction.recordID == record.id {
            entries.append(RecordTrailEntry(
                id: "correction.\(correction.id.uuidString)", date: correction.createdAt, kind: .correction(correction)
            ))
        }
        return entries.sorted { lhs, rhs in
            lhs.date == rhs.date ? lhs.rank > rhs.rank : lhs.date > rhs.date
        }
    }
}
