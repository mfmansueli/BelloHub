//
//  VisitSummary.swift
//  BelloHub
//

import Foundation

/// One visit on a client's timeline: its record as it reads now, the day it happened, and what belongs to it by link
/// (photos and incidents whose `recordID` is this record). Nothing is attached by date.
struct VisitSummary: Identifiable, Equatable, Sendable {
    /// The record with every correction applied (`RecordCurrentValues.applied`).
    let record: TreatmentRecord
    let visitDate: RecordVisitDate
    /// This visit's photos, oldest first, so "before" reads before "after".
    let photos: [Photo]
    let incidents: [Incident]
    let state: VisitRecordState
    /// One short line of what was done (technique, products, result, notes), nil when the record says nothing yet.
    let summary: String?

    var id: UUID { record.id }
}
