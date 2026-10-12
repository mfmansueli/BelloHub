//
//  SubscriptionSnapshot.swift
//  BelloHub
//

import Foundation

/// The last plan state proven by the store's signed data, kept on this iPhone so the plan works offline and before
/// the store answers at launch (D59). It holds no personal data: a kind, a period, the signed end and a time.
///
/// It never outlives what Apple signed: offline, a plan counts only until `accessEndsAt` (the signed expiry, or the
/// signed end of the grace period), measured against the latest time this iPhone has ever shown it
/// (`latestSeenAt`), so turning the clock back cannot stretch a plan. A plan with no signed end is not trusted offline.
struct SubscriptionSnapshot: Codable, Equatable, Sendable {
    enum Kind: String, Codable, Sendable {
        case none
        case active
        case grace
    }

    let kind: Kind
    let period: String?
    let accessEndsAt: Date?
    let willRenew: Bool
    /// The latest "now" this iPhone has shown the plan code; only ever moves forward.
    let latestSeenAt: Date

    init(state: SubscriptionState, seenAt: Date) {
        switch state {
        case .unknown, .none:
            kind = .none
            period = nil
            accessEndsAt = nil
            willRenew = false
        case .active(let plan, let expiresAt, let renews):
            kind = .active
            period = plan.rawValue
            accessEndsAt = expiresAt
            willRenew = renews
        case .inGracePeriod(let plan, let expiresAt):
            kind = .grace
            period = plan.rawValue
            accessEndsAt = expiresAt
            willRenew = true
        }
        latestSeenAt = seenAt
    }

    /// The same snapshot, having now also seen `now` (never earlier than what it saw).
    func seen(at now: Date) -> SubscriptionSnapshot {
        SubscriptionSnapshot(copying: self, latestSeenAt: max(latestSeenAt, now))
    }

    /// What the snapshot still proves at `now`.
    func state(at now: Date) -> SubscriptionState {
        let effectiveNow = max(now, latestSeenAt)
        guard kind != .none, let plan = period.flatMap(PlanPeriod.init(rawValue:)), let end = accessEndsAt,
              end > effectiveNow else { return .none }
        return kind == .grace
            ? .inGracePeriod(period: plan, expiresAt: end)
            : .active(period: plan, expiresAt: end, willRenew: willRenew)
    }

    private init(copying other: SubscriptionSnapshot, latestSeenAt: Date) {
        kind = other.kind
        period = other.period
        accessEndsAt = other.accessEndsAt
        willRenew = other.willRenew
        self.latestSeenAt = latestSeenAt
    }
}
