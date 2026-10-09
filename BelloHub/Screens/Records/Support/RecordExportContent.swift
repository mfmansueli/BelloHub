//
//  RecordExportContent.swift
//  BelloHub
//

import Foundation

/// Exactly what goes into one exported PDF, already cut down by `RecordExportSelector`: nothing in it is private unless
/// the options let it be. The builder and the exporter only draw it.
struct RecordExportContent: Equatable, Sendable {
    struct Health: Equatable, Sendable {
        var allergies: [String]
        var sensitivities: [String]
        /// Her own important note about the client: only in a health professional's copy.
        var importantNote: String?

        var isEmpty: Bool { allergies.isEmpty && sensitivities.isEmpty && importantNote == nil }
    }

    struct Treatment: Equatable, Sendable {
        /// Internal notes are nil here unless the options included them.
        var record: TreatmentRecord
        var corrections: [RecordCorrection]
    }

    let options: ExportOptions
    let clientName: String
    let health: Health?
    /// Kind and date only: the signature image and the typed signature never leave the vault in an export.
    let consents: [Consent]
    let treatments: [Treatment]
    let incidents: [Incident]
    let photos: [Photo]
}
