//
//  SubscriptionState.swift
//  BelloHub
//

import Foundation

/// Where her Bello Hub Pro subscription stands, as the store (and, from S8, the server) says. Read by the gate
/// (`hasActivePlan`) and by the Plan screen. The app only reads it; the server re-verifies before it unlocks anything
/// (CLAUDE.md section 2).
enum SubscriptionState: Equatable, Sendable {
    /// Not looked up yet (the store has not answered).
    case unknown
    /// No plan.
    case none
    /// A plan that renews, or that runs until `expiresAt` when renewal is off.
    case active(period: PlanPeriod, expiresAt: Date?, willRenew: Bool)
    /// A plan whose last payment failed: Apple keeps access for a while and asks her to fix the card.
    case inGracePeriod(period: PlanPeriod, expiresAt: Date?)

    var hasActivePlan: Bool {
        switch self {
        case .active, .inGracePeriod: true
        case .unknown, .none: false
        }
    }

    var period: PlanPeriod? {
        switch self {
        case .active(let period, _, _), .inGracePeriod(let period, _): period
        case .unknown, .none: nil
        }
    }
}
