//
//  RecordHistoryItem.swift
//  BelloHub
//

import Foundation

/// One treatment record as 4.7 shows it: the record, its trail and where it stands against the 24-hour lock.
struct RecordHistoryItem: Identifiable, Equatable, Sendable {
    let record: TreatmentRecord
    let trail: [RecordTrailEntry]
    let corrections: [RecordCorrection]
    let isLocked: Bool
    /// Time left to edit directly, nil once locked.
    let remaining: TimeInterval?

    var id: UUID { record.id }
}
