//
//  VisitRecordState.swift
//  BelloHub
//

import Foundation

/// Where one visit's record stands, for the chip on its card and the status line of its details.
enum VisitRecordState: Equatable, Sendable {
    /// Saved as she goes, not finalized yet.
    case draft
    /// Finalized and still editable directly for `remaining`.
    case open(remaining: TimeInterval)
    /// Finalized and locked: it changes only by a logged correction.
    case locked

    static func of(_ record: TreatmentRecord, now: Date) -> VisitRecordState {
        if record.isDraft { return .draft }
        if let remaining = RecordLockPolicy.remaining(of: record, now: now) { return .open(remaining: remaining) }
        return .locked
    }
}
