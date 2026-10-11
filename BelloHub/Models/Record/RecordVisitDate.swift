//
//  RecordVisitDate.swift
//  BelloHub
//

import Foundation

/// The day a record stands for on screen, and where that day came from. One owner for the rule, so the timeline,
/// the visit details, "Before you start" and the export never disagree.
///
/// Records written before `performedAt` existed are never given an invented date: if the record was made for an
/// appointment, that appointment's start is a real, recorded day; otherwise the visit day is unknown and the screen
/// shows when the record was written, saying so.
struct RecordVisitDate: Hashable, Sendable {
    enum Source: Hashable, Sendable {
        /// She set the visit day on the record.
        case recorded
        /// The start of the appointment the record was made for.
        case appointment
        /// No visit day is known: `date` is when the record was written.
        case writtenOnly
    }

    let date: Date
    let source: Source

    /// True when `date` is the day of the treatment, not only the day it was written.
    var isVisitDay: Bool { source != .writtenOnly }

    static func resolve(_ record: TreatmentRecord, appointmentStart: Date?) -> RecordVisitDate {
        if let performedAt = record.performedAt {
            return RecordVisitDate(date: performedAt, source: .recorded)
        }
        if record.appointmentID != nil, let appointmentStart {
            return RecordVisitDate(date: appointmentStart, source: .appointment)
        }
        return RecordVisitDate(date: record.createdAt, source: .writtenOnly)
    }

    /// Resolves against the client's appointments, matching only by the record's own `appointmentID`.
    static func resolve(_ record: TreatmentRecord, appointments: [UUID: Appointment]) -> RecordVisitDate {
        resolve(record, appointmentStart: record.appointmentID.flatMap { appointments[$0]?.startsAt })
    }
}
