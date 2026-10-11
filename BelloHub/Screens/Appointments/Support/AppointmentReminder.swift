//
//  AppointmentReminder.swift
//  BelloHub
//

import Foundation

/// Where the reminder of a visit stands (3.2): confirmed by the client, its chat opened or marked as sent by her and
/// no answer yet, or nothing yet. Opening WhatsApp is never called "sent" (routine-a item 6): `waiting` carries the
/// honest `MessageDeliveryState`.
enum AppointmentReminder: Equatable, Sendable {
    case notSent
    /// The chat was opened (or she said she sent it) and the client has not answered: "Remind again" is offered.
    case waiting(MessageDeliveryState)
    case confirmed(at: Date)

    static func make(for appointment: Appointment) -> AppointmentReminder {
        guard appointment.status.holdsTime else { return .notSent }
        if let confirmed = appointment.clientConfirmedAt { return .confirmed(at: confirmed) }
        let state = MessageDeliveryState.reminder(of: appointment)
        return state == .readyToSend ? .notSent : .waiting(state)
    }
}
