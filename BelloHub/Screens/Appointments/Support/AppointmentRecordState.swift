//
//  AppointmentRecordState.swift
//  BelloHub
//

import Foundation

/// Whether the appointment already has its record (matched by the record's `appointmentID` only).
enum AppointmentRecordState: Equatable, Sendable {
    case none
    case draft
    case finalized

    static func of(_ record: TreatmentRecord?) -> AppointmentRecordState {
        guard let record else { return .none }
        return record.isDraft ? .draft : .finalized
    }

    /// The record action for this state: register, continue the draft, or open the record.
    var action: AppointmentAction {
        switch self {
        case .none: .registerVisit
        case .draft: .continueRecord
        case .finalized: .openRecord
        }
    }
}
