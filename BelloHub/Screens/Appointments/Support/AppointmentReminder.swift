//
//  AppointmentReminder.swift
//  BelloHub
//

import Foundation

/// Where the reminder of a visit stands (3.2): sent and waiting for an answer, confirmed by the client, or not sent.
enum AppointmentReminder: Equatable, Sendable {
    case notSent
    /// Sent, and the client has not answered: the detail offers "Remind again".
    case waiting(sentAt: Date)
    case confirmed(at: Date)

    static func make(for appointment: Appointment) -> AppointmentReminder {
        guard appointment.status.holdsTime else { return .notSent }
        if let confirmed = appointment.clientConfirmedAt { return .confirmed(at: confirmed) }
        if let sent = appointment.reminderSentAt { return .waiting(sentAt: sent) }
        return .notSent
    }
}
