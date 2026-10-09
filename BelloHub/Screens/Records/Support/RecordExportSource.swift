//
//  RecordExportSource.swift
//  BelloHub
//

import Foundation

/// Everything the vault holds about one client that an export may draw from, before `RecordExportSelector` cuts it
/// down by audience, switches and period.
struct RecordExportSource: Sendable {
    let client: Client
    let records: [TreatmentRecord]
    let corrections: [RecordCorrection]
    let incidents: [Incident]
    let photos: [Photo]
    let consents: [ConsentRecord]
}
