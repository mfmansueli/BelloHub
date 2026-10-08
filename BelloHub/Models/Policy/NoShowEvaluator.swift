//
//  NoShowEvaluator.swift
//  BelloHub
//

import Foundation

/// Counts what counts against a client under the professional's `NoShowPolicy` (D13). A cancellation made by the
/// professional never counts, a forgiven no-show never counts, and old ones stop counting by themselves.
enum NoShowEvaluator {
    static func status(policy: NoShowPolicy, client: Client, appointments: [Appointment], now: Date, calendar: Calendar)
        -> NoShowStatus {
        let since = windowStart(policy: policy, client: client, now: now, calendar: calendar)
        let count = appointments.filter { appointment in
            appointment.clientID == client.id && appointment.startsAt >= since && appointment.startsAt <= now
                && counts(appointment, policy: policy)
        }.count
        return NoShowStatus(counted: count, limit: policy.limit, isProtectionOn: policy.isOn)
    }

    /// The action to apply when the limit is reached, or nil.
    static func actionToApply(policy: NoShowPolicy, status: NoShowStatus) -> NoShowAction? {
        status.limitReached ? policy.action : nil
    }

    static func counts(_ appointment: Appointment, policy: NoShowPolicy) -> Bool {
        switch appointment.status {
        case .noShow:
            return !appointment.noShowForgiven
        case .cancelled:
            return policy.lateCancelCounts && appointment.cancelledBy == .client && appointment.isLateCancellation
        case .booked, .confirmed, .completed:
            return false
        }
    }

    /// The start of what counts: the counting period back from now, or the day her count was reset, whichever is later.
    static func windowStart(policy: NoShowPolicy, client: Client, now: Date, calendar: Calendar) -> Date {
        let periodStart = calendar.date(byAdding: .month, value: -policy.countingMonths, to: now) ?? .distantPast
        return max(periodStart, client.noShowCountResetAt ?? .distantPast)
    }
}
