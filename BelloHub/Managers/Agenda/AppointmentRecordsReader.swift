//
//  AppointmentRecordsReader.swift
//  BelloHub
//

import Foundation

/// Reads one client's records, corrections and photos for an appointment and hands them to the pure
/// `AppointmentRecords`, like `PreVisitReader` does for the checklist. The appointment screen and "Before you start"
/// both use it, so they show the same previous visit.
@MainActor
struct AppointmentRecordsReader {
    let repository: any ClientRecordRepository

    func records(
        for visit: VisitContext, appointments: [Appointment], now: Date, list: ([String]) -> String
    ) async throws -> AppointmentRecords {
        let clientID = visit.client.id
        let records = try await repository.records(for: clientID)
        var corrections: [RecordCorrection] = []
        for record in records where !record.isDraft {
            corrections += try await repository.corrections(for: record.id)
        }
        return AppointmentRecords.make(
            appointmentID: visit.appointment.id, records: records, corrections: corrections,
            appointments: appointments, photos: try await repository.photos(for: clientID), now: now, list: list
        )
    }
}
