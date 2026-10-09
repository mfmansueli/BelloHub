//
//  RunningLateRules.swift
//  BelloHub
//

import Foundation

/// The rules of the "running late" sheet (2.12): how long, and whom to tell. The calendar does not change; she only
/// writes to the clients, one chat each. Pure.
enum RunningLateRules {
    /// The delays she can pick, in minutes (10 to 45).
    static let delayOptions = [10, 15, 20, 30, 45]
    static let defaultDelay = 15
    /// From this delay on, the sheet suggests offering to reschedule.
    static let longWaitMinutes = 30

    static func isLongWait(_ minutes: Int) -> Bool {
        minutes >= longWaitMinutes
    }

    /// The visits whose clients get the message: this one and every later one the same day that still holds its time,
    /// in order. An earlier visit, or a closed one, is not affected by her being late.
    static func recipients(
        startingWith anchor: Appointment, among appointments: [Appointment], calendar: Calendar
    ) -> [Appointment] {
        let later = appointments.filter {
            $0.id != anchor.id && $0.status.holdsTime && $0.startsAt >= anchor.startsAt
                && calendar.isDate($0.startsAt, inSameDayAs: anchor.startsAt)
        }
        return ([anchor] + later).sorted { ($0.startsAt, $0.id.uuidString) < ($1.startsAt, $1.id.uuidString) }
    }
}
