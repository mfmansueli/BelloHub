//
//  RecordLockPolicy.swift
//  BelloHub
//

import Foundation

/// A treatment record, an incident and their notes lock 24 hours after creation. After that every change is a
/// logged correction, never a silent edit (docs/01-PRODUCT.md rule 3). The lock is 24 real hours, not a calendar
/// day, so it behaves the same across a daylight-saving change.
enum RecordLockPolicy {
    static let lockInterval: TimeInterval = 24 * 60 * 60

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
}
