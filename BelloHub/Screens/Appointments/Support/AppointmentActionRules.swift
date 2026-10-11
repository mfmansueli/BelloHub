//
//  AppointmentActionRules.swift
//  BelloHub
//

import Foundation

/// Which actions a visit allows, by its status and the time (3.2). One owner: the detail screen only lays out what this
/// returns, so a button that should not exist can never be shown. Every change still goes through `AppointmentService`.
///
/// - Still ahead, in progress, or past but not closed (`booked` / `confirmed`): she can write to the client, move or
///   cancel it (she may cancel at any time, and her own cancellation never counts against the client, D13).
/// - "Didn't show up" exists only once the start has passed: a visit that has not started cannot be missed.
/// - "Mark completed" exists once the visit has started.
/// - "Running late" (she tells the next clients) exists until the visit ends.
/// - A closed visit (`completed`, `cancelled`, `noShow`) only keeps the message: aftercare, a new time, a friendly
///   note.
enum AppointmentActionRules {
    static func layout(for appointment: Appointment, now: Date) -> AppointmentActionLayout {
        guard appointment.status.holdsTime else {
            return AppointmentActionLayout(primary: nil, quick: [.message], secondary: [])
        }
        if now < appointment.startsAt {
            return AppointmentActionLayout(
                primary: .beforeYouStart, quick: [.message, .runningLate], secondary: [.reschedule, .cancel]
            )
        }
        if now < appointment.endsAt {
            return AppointmentActionLayout(
                primary: .beforeYouStart, quick: [.complete, .message, .runningLate],
                secondary: [.reschedule, .noShow, .cancel]
            )
        }
        return AppointmentActionLayout(
            primary: .complete, quick: [.message], secondary: [.noShow, .reschedule, .cancel]
        )
    }
}
