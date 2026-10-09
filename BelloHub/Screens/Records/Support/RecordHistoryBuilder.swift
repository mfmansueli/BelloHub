//
//  RecordHistoryBuilder.swift
//  BelloHub
//

import Foundation

/// Turns the vault's records and corrections into the history list, newest record first.
enum RecordHistoryBuilder {
    static func items(
        records: [TreatmentRecord], corrections: [RecordCorrection], now: Date
    ) -> [RecordHistoryItem] {
        records
            .sorted { $0.createdAt > $1.createdAt }
            .map { record in
                let own = corrections.filter { $0.recordID == record.id }
                return RecordHistoryItem(
                    record: record,
                    trail: RecordTrailBuilder.entries(for: record, corrections: own, now: now),
                    corrections: own,
                    isLocked: RecordLockPolicy.isLocked(lockedAt: record.lockedAt, now: now),
                    remaining: RecordLockPolicy.remaining(lockedAt: record.lockedAt, now: now)
                )
            }
    }
}
