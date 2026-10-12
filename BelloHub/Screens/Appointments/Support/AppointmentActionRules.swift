//
//  AppointmentActionRules.swift
//  BelloHub
//

import Foundation

/// Which actions a visit allows, and which one leads. Booking and record are separate: "Mark completed" closes the
/// booking, the record action (register, continue, open) documents the treatment, and neither requires the other.
/// While the visit runs, registering it leads; once it is over, closing the booking leads; a completed booking leads
/// to its record. A cancelled booking or a no-show has nothing to document.
enum AppointmentActionRules {
    static func layout(
        for appointment: Appointment, record: AppointmentRecordState = .none, now: Date
    ) -> AppointmentActionLayout {
        let documentAction = record.action
        guard appointment.status.holdsTime else {
            guard appointment.status == .completed else {
                return AppointmentActionLayout(primary: nil, quick: [.message], secondary: [])
            }
            return AppointmentActionLayout(primary: documentAction, quick: [.message], secondary: [])
        }
        if now < appointment.startsAt {
            // Photos "before" may be taken before the start: a draft already started stays one tap away.
            let quick: [AppointmentAction] = record == .none
                ? [.message, .runningLate] : [documentAction, .message, .runningLate]
            return AppointmentActionLayout(primary: .beforeYouStart, quick: quick, secondary: [.reschedule, .cancel])
        }
        if now < appointment.endsAt {
            return AppointmentActionLayout(
                primary: documentAction, quick: [.complete, .beforeYouStart, .message],
                secondary: [.runningLate, .reschedule, .noShow, .cancel]
            )
        }
        return AppointmentActionLayout(
            primary: .complete, quick: [documentAction, .message], secondary: [.noShow, .reschedule, .cancel]
        )
    }
}
