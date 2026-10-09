//
//  CancelNotice.swift
//  BelloHub
//

import Foundation

/// What the cancel sheet tells her about the effect on the client (3.5). A cancellation by the professional never
/// counts (D13). One by the client is late inside the policy's free window, and counts only when the no-show policy
/// says so. The policy passed in is the one that applies to this visit (D47: for a visit made by hand, today's).
enum CancelNotice: Equatable, Sendable {
    /// She cancels: it does not count against the client.
    case byProfessional
    /// The client cancels in time: free, nothing is noted.
    case clientInTime(freeWindowHours: Int)
    /// The client cancels inside the free window. `counts` is true when the no-show rule counts late cancellations.
    case clientLate(freeWindowHours: Int, counts: Bool)

    static func make(
        by who: CancelledBy, policy: CancellationPolicy, noShow: NoShowPolicy, startsAt: Date, now: Date
    ) -> CancelNotice {
        guard who == .client else { return .byProfessional }
        guard CancellationEvaluator.isLateCancellation(policy: policy, startsAt: startsAt, cancelledAt: now) else {
            return .clientInTime(freeWindowHours: policy.freeWindowHours)
        }
        return .clientLate(freeWindowHours: policy.freeWindowHours, counts: noShow.isOn && noShow.lateCancelCounts)
    }

    /// The visit will be stored as a late cancellation.
    var isLate: Bool {
        if case .clientLate = self { return true }
        return false
    }

    /// The visit will count toward the client's limit.
    var countsAgainstClient: Bool {
        if case .clientLate(_, let counts) = self { return counts }
        return false
    }
}
