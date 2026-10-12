//
//  RecordForAppointment.swift
//  BelloHub
//

import Foundation

/// Finds the record already made for an appointment, so opening "Register treatment" twice for the same visit opens
/// the same record instead of starting a second one. Matching is only by the record's `appointmentID`, never by date
/// or service: two visits on the same day are two records.
enum RecordForAppointment {
    /// The record for `appointmentID`, preferring a finalized one over a draft and then the newest. Nil when there is
    /// none, or when no appointment is given.
    static func existing(in records: [TreatmentRecord], appointmentID: UUID?) -> TreatmentRecord? {
        guard let appointmentID else { return nil }
        return records
            .filter { $0.appointmentID == appointmentID }
            .max { lhs, rhs in
                if lhs.status != rhs.status { return lhs.isDraft }
                return lhs.createdAt < rhs.createdAt
            }
    }

    /// The ids of the appointments that already have a record (draft or finalized).
    static func recordedAppointmentIDs(_ records: [TreatmentRecord]) -> Set<UUID> {
        Set(records.compactMap(\.appointmentID))
    }
}
