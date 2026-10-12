//
//  RecordLockPolicy.swift
//  BelloHub
//

import Foundation

/// A finalized treatment record locks 24 hours after it was finalized, an incident 24 hours after it was written.
/// After that every change is a logged correction, never a silent edit (docs/01-PRODUCT.md rule 3). The lock is 24
/// real hours, not a calendar day, so it behaves the same across a daylight-saving change.
///
/// A draft never locks: it is her unfinished note, not yet a record anyone relies on. Records from before drafts
/// existed were final at creation, so for them "finalized" and "created" are the same moment and nothing changes.
enum RecordLockPolicy {
    static let lockInterval: TimeInterval = 24 * 60 * 60
    /// The `lockedAt` a draft carries, so every existing lock check reads it as open without a special case.
    static let draftLockedAt = Date.distantFuture

    enum EditPath: Equatable {
        case editDirectly
        case addCorrection
    }

    static func lockedAt(createdAt: Date) -> Date {
        createdAt.addingTimeInterval(lockInterval)
    }

    /// Locked from the exact moment `lockedAt` arrives: at 23:59:59 it is still editable, at 24:00:00 it is not.
    static func isLocked(lockedAt: Date, now: Date) -> Bool {
        now >= lockedAt
    }

    static func editPath(lockedAt: Date, now: Date) -> EditPath {
        isLocked(lockedAt: lockedAt, now: now) ? .addCorrection : .editDirectly
    }

    /// Time left to edit directly, or nil once locked. For the "locks in 3 h" hint.
    static func remaining(lockedAt: Date, now: Date) -> TimeInterval? {
        isLocked(lockedAt: lockedAt, now: now) ? nil : lockedAt.timeIntervalSince(now)
    }

    /// Time left before a record locks, or nil when it is locked **or still a draft** (a draft has no countdown).
    static func remaining(of record: TreatmentRecord, now: Date) -> TimeInterval? {
        record.isDraft ? nil : remaining(lockedAt: record.lockedAt, now: now)
    }
}
