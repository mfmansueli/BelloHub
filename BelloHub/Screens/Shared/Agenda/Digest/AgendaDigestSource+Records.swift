//
//  AgendaDigestSource+Records.swift
//  BelloHub
//

import Foundation

@MainActor
extension AgendaDigestSource {
    /// Records still owed (`RecordPending`), from the same data as the rest of the digest. Home and Alerts both read
    /// it, so the same visit is the same line in both.
    func records(now: Date) -> RecordPending {
        RecordPending.make(
            appointments: service.appointments, marks: service.recordMarks, clients: service.clients, now: now,
            calendar: days.calendar
        )
    }

    /// Client names by id, for the lines of the records still owed.
    var clientNames: [UUID: String] {
        Dictionary(service.clients.map { ($0.id, $0.name) }, uniquingKeysWith: { first, _ in first })
    }
}
