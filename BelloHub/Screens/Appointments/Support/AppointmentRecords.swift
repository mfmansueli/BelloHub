//
//  AppointmentRecords.swift
//  BelloHub
//

import Foundation

/// What the client's records say about one appointment: the record written for it (by its stored link) and her last
/// finalized visit before it. Pure, shared by the appointment screen and "Before you start" so both read the same
/// visit.
struct AppointmentRecords: Equatable, Sendable {
    /// The record linked to this appointment, a draft or finalized; nil when nothing was written yet.
    let record: TreatmentRecord?
    /// Her latest finalized visit other than this appointment's, with its photos and current values.
    let previousVisit: VisitSummary?

    static let empty = AppointmentRecords(record: nil, previousVisit: nil)

    static func make(
        appointmentID: UUID, records: [TreatmentRecord], corrections: [RecordCorrection] = [],
        appointments: [Appointment], photos: [Photo], now: Date, list: ([String]) -> String
    ) -> AppointmentRecords {
        let record = RecordForAppointment.existing(in: records, appointmentID: appointmentID)
        // Drafts are unfinished; the previous visit is the last one she closed.
        let earlier = records.filter { !$0.isDraft && $0.appointmentID != appointmentID }
        guard !earlier.isEmpty else { return AppointmentRecords(record: record, previousVisit: nil) }
        let timeline = ClientTimelineBuilder.make(
            .init(records: earlier, corrections: corrections, appointments: appointments, photos: photos),
            now: now, list: list
        )
        return AppointmentRecords(record: record, previousVisit: timeline.lastVisit)
    }

    /// "Remember today": the note she left for this visit on the previous one, exactly as written.
    var rememberToday: String? {
        previousVisit?.record.nextVisitReminder.flatMap { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .flatMap { $0.isEmpty ? nil : $0 }
    }
}
