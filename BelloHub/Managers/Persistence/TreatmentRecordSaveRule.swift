//
//  TreatmentRecordSaveRule.swift
//  BelloHub
//

import Foundation

/// What both repositories store when a treatment record is saved, so the lock and the draft rules have one owner.
///
/// - A new draft stays open (`RecordLockPolicy.draftLockedAt`).
/// - A new finalized record keeps the lock it was built with.
/// - An edit never moves `createdAt`, and never edits a locked record (`recordLocked`).
/// - A draft that is saved as finalized starts its 24-hour lock at the repository's `now`, so a caller cannot
///   stretch the lock by passing a later time.
/// - A finalized record never goes back to being a draft, and its finalize time and lock never move.
enum TreatmentRecordSaveRule {
    static func stored(
        _ record: TreatmentRecord, existing: TreatmentRecord?, now: Date
    ) throws(VaultRepositoryError) -> TreatmentRecord {
        var stored = record
        guard let existing else {
            if record.isDraft {
                stored.finalizedAt = nil
                stored.lockedAt = RecordLockPolicy.draftLockedAt
            }
            return stored
        }
        guard !RecordLockPolicy.isLocked(lockedAt: existing.lockedAt, now: now) else {
            throw .recordLocked
        }
        stored.createdAt = existing.createdAt
        switch (existing.status, record.status) {
        case (.draft, .draft):
            stored.finalizedAt = nil
            stored.lockedAt = RecordLockPolicy.draftLockedAt
        case (.draft, .finalized):
            stored.finalizedAt = now
            stored.lockedAt = RecordLockPolicy.lockedAt(createdAt: now)
        case (.finalized, _):
            stored.status = .finalized
            stored.finalizedAt = existing.finalizedAt
            stored.lockedAt = existing.lockedAt
        }
        return stored
    }
}
