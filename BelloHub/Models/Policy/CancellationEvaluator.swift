//
//  CancellationEvaluator.swift
//  BelloHub
//

import Foundation

/// Applies a `CancellationPolicy` to one visit. The booking page evaluates the policy **as of the booking** (a snapshot
/// stored with it) so a later edit never changes a client's rights retroactively.
enum CancellationEvaluator {
    static func decide(policy: CancellationPolicy, startsAt: Date, now: Date, rescheduleCount: Int)
        -> CancellationDecision {
        let hours = startsAt.timeIntervalSince(now) / 3600
        guard hours > 0 else {
            return CancellationDecision(cancel: .unavailable, reschedule: .unavailable, isInsideFreeWindow: false,
                                        hoursUntilStart: hours)
        }
        // Free up to and including the boundary: exactly 24 h before is still inside a 24 h window.
        let inside = hours >= Double(policy.freeWindowHours)
        return CancellationDecision(
            cancel: cancel(policy: policy, inside: inside),
            reschedule: reschedule(policy: policy, inside: inside, rescheduleCount: rescheduleCount),
            isInsideFreeWindow: inside,
            hoursUntilStart: hours
        )
    }

    /// Whether a cancellation by the client at `cancelledAt` is late. A cancellation by the professional never is.
    static func isLateCancellation(policy: CancellationPolicy, startsAt: Date, cancelledAt: Date) -> Bool {
        startsAt.timeIntervalSince(cancelledAt) / 3600 < Double(policy.freeWindowHours)
    }

    /// How long the professional holds the time when a client is late.
    static func graceDeadline(policy: CancellationPolicy, startsAt: Date) -> Date {
        startsAt.addingTimeInterval(TimeInterval(policy.graceMinutes * 60))
    }

    private static func cancel(policy: CancellationPolicy, inside: Bool) -> CancellationDecision.Cancel {
        if inside { return .free }
        return policy.afterWindowCancel == .allow ? .allowedWithWarning : .askByMessage
    }

    private static func reschedule(policy: CancellationPolicy, inside: Bool, rescheduleCount: Int)
        -> CancellationDecision.Reschedule {
        guard policy.clientCanReschedule else { return .message }
        if let maximum = policy.maxReschedules, rescheduleCount >= maximum { return .message }
        if inside { return .direct }
        return policy.afterWindowReschedule == .request ? .request : .message
    }
}
