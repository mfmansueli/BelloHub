//
//  RecordExportSelector.swift
//  BelloHub
//

import Foundation

/// Chooses what an export contains from what the vault holds. The privacy rules live here and nowhere else:
/// - the client's copy never includes internal notes or what to remember next time, nor corrections of them;
/// - drafts are in no copy: they are not a record until she finalizes them;
/// - the client's copy includes only photos that are shared with the client or in the portfolio;
/// - the client's copy never includes her important note;
/// - the photo or file of a signed paper is never included, only the label, the status and the date of each consent
///   record (D55).
enum RecordExportSelector {
    static func content(
        from source: RecordExportSource, options: ExportOptions, now: Date, calendar: Calendar
    ) -> RecordExportContent {
        let client = source.client
        let records = source.records
        let corrections = source.corrections
        let incidents = source.incidents
        let photos = source.photos
        let consents = source.consents
        let start = options.period.start(now: now, calendar: calendar)
        let keepsNotes = options.effectiveIncludesInternalNotes
        let isDoctor = options.audience == .healthProfessional
        return RecordExportContent(
            options: options,
            clientName: client.name,
            health: options.includeHealth ? health(of: client, isDoctor: isDoctor) : nil,
            consents: options.includeConsent ? ConsentRecord.newestFirst(consents).map(withoutDocument) : [],
            treatments: options.includeTreatments
                ? treatments(records, corrections: corrections, since: start, keepsNotes: keepsNotes) : [],
            incidents: options.includeTreatments
                ? incidents.filter { within($0.occurredAt, since: start) }.sorted { $0.occurredAt > $1.occurredAt }
                : [],
            photos: options.includePhotos ? visiblePhotos(photos, since: start, isDoctor: isDoctor) : []
        )
    }

    // MARK: - Private

    private static func health(of client: Client, isDoctor: Bool) -> RecordExportContent.Health? {
        let health = RecordExportContent.Health(
            allergies: client.allergies, sensitivities: client.sensitivities,
            importantNote: isDoctor ? client.importantNote : nil
        )
        return health.isEmpty ? nil : health
    }

    private static func within(_ date: Date, since start: Date?) -> Bool {
        start.map { date >= $0 } ?? true
    }

    /// Her own working notes, never in the client's copy: internal notes and what to remember next time.
    private static let privateFieldKeys: Set<String> = [
        RecordCorrectableField.notes.rawValue, RecordCorrectableField.nextVisitReminder.rawValue
    ]

    private static func withoutDocument(_ consent: ConsentRecord) -> ConsentRecord {
        var plain = consent
        plain.document = nil
        return plain
    }

    private static func treatments(
        _ records: [TreatmentRecord], corrections: [RecordCorrection], since start: Date?, keepsNotes: Bool
    ) -> [RecordExportContent.Treatment] {
        // A draft is not a record yet: it stays out of every copy until she finalizes it.
        records
            .filter { !$0.isDraft && within($0.performedAt ?? $0.createdAt, since: start) }
            .sorted { ($0.performedAt ?? $0.createdAt) > ($1.performedAt ?? $1.createdAt) }
            .map { record in
                var shown = record
                if !keepsNotes {
                    shown.notes = nil
                    shown.nextVisitReminder = nil
                }
                let own = corrections
                    .filter { $0.recordID == record.id }
                    .filter { keepsNotes || !privateFieldKeys.contains($0.fieldKey) }
                    .sorted { $0.createdAt > $1.createdAt }
                return RecordExportContent.Treatment(record: shown, corrections: own)
            }
    }

    private static func visiblePhotos(_ photos: [Photo], since start: Date?, isDoctor: Bool) -> [Photo] {
        PhotoComparisonRules.timeline(photos)
            .filter { within($0.takenAt, since: start) }
            .filter { isDoctor || $0.visibility != .professionalOnly }
    }
}
