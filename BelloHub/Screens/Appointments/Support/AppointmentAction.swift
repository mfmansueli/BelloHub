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
}
