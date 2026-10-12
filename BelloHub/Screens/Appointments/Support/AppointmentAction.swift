//
//  AppointmentAction.swift
//  BelloHub
//

/// Something she can do from a visit's detail (3.2).
enum AppointmentAction: String, CaseIterable, Sendable {
    case beforeYouStart
    case complete
    case message
    case runningLate
    case reschedule
    case noShow
    case cancel
    /// Opens the visit form for this appointment (no record yet).
    case registerVisit
    /// Opens the draft already started for this appointment.
    case continueRecord
    /// Opens the finalized record's details.
    case openRecord
}
