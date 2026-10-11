//
//  AppointmentTransitions.swift
//  BelloHub
//

import Foundation

/// How an appointment changes when she books, moves, cancels or closes it. One owner of these rules (CLAUDE.md
/// section 2): the services and every screen call these, so the calendar, the client's history and the booking page
/// never disagree. Time comes in as `now`.
enum AppointmentTransitions {
    /// Moves a visit to a new start, keeping its length. Counts the move and puts it back to `booked` (a client's
    /// earlier confirmation no longer applies to the new time).
    static func rescheduled(_ appointment: Appointment, to start: Date, now: Date) -> Appointment {
        var moved = appointment
        moved.startsAt = start
        moved.endsAt = start.addingTimeInterval(TimeInterval(appointment.totalMinutes * 60))
        moved.rescheduleCount += 1
        moved.status = .booked
        moved.clientConfirmedAt = nil
        moved.reminderSentAt = nil
        moved.reminderMarkedSentAt = nil
        moved.lateByMinutes = nil
        moved.updatedAt = now
        return moved
    }

    /// Cancels a visit. A cancellation by the professional is never late (D13); one by the client is late when it
    /// comes inside the policy's free window, which the policy of **this appointment's booking** decides.
    static func cancelled(
        _ appointment: Appointment, by who: CancelledBy, policy: CancellationPolicy, now: Date
    ) -> Appointment {
        var cancelled = appointment
        cancelled.status = .cancelled
        cancelled.cancelledAt = now
        cancelled.cancelledBy = who
        cancelled.isLateCancellation = who == .client
            && CancellationEvaluator.isLateCancellation(
                policy: policy, startsAt: appointment.startsAt, cancelledAt: now
            )
        cancelled.updatedAt = now
        return cancelled
    }

    /// Marks a visit whose time has passed as a no-show. `forgive` keeps it out of the client's count (D13).
    static func noShow(_ appointment: Appointment, forgive: Bool, now: Date) -> Appointment {
        var missed = appointment
        missed.status = .noShow
        missed.noShowForgiven = forgive
        missed.updatedAt = now
        return missed
    }

    /// The visit took place.
    static func completed(_ appointment: Appointment, now: Date) -> Appointment {
        var done = appointment
        done.status = .completed
        done.updatedAt = now
        return done
    }

    /// The client said she is running late; the visit keeps its time.
    static func late(_ appointment: Appointment, byMinutes minutes: Int, now: Date) -> Appointment {
        var late = appointment
        late.lateByMinutes = max(0, minutes)
        late.updatedAt = now
        return late
    }
}
