//
//  SubscriptionState.swift
//  BelloHub
//

import Foundation

/// Where her Bello Hub Pro subscription stands, as the App Store's signed data proves it on this iPhone (D59:
/// `EntitlementRules`, `DeviceSubscriptionVerifier`). Read by the registration gate (`hasActivePlan`) and by the Plan
/// screen. The server does not know it (D59 replaces the server verification of D33).
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
