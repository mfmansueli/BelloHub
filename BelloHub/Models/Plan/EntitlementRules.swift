//
//  EntitlementRules.swift
//  BelloHub
//

import Foundation

/// Whether she has the plan, from the store's verified entitlements (D59). Pure: the store's facts and `now` come in.
///
/// - A refunded or revoked transaction never counts, whatever else it says.
/// - "Subscribed" counts until its signed expiry; "grace period" counts until the signed end of the grace period, so a
///   failed payment does not lock her out while Apple retries with grace on.
/// - "Billing retry" without grace, and "expired", do not count.
/// - Products that are not this plan's are ignored.
/// When several count, an active plan wins over one in grace, then the one that lasts longer.
enum EntitlementRules {
    static func state(from entitlements: [StoreEntitlement], products: PlanProducts, now: Date) -> SubscriptionState {
        let candidates = entitlements.compactMap { candidate($0, products: products, now: now) }
        let best = candidates.max { lhs, rhs in
            if lhs.isGrace != rhs.isGrace { return lhs.isGrace }
            return (lhs.end ?? .distantFuture) < (rhs.end ?? .distantFuture)
        }
        return best?.state ?? .none
    }

    // MARK: - Private

    private struct Candidate {
        let state: SubscriptionState
        let end: Date?
        let isGrace: Bool
    }

    private static func candidate(_ entitlement: StoreEntitlement, products: PlanProducts, now: Date) -> Candidate? {
        guard let period = products.period(forProductID: entitlement.productID),
              entitlement.revokedAt == nil else { return nil }
        switch entitlement.renewal {
        case .subscribed:
            // Apple's signed status says subscribed; a missing expiry is taken as Apple's word.
            if let end = entitlement.expiresAt, end <= now { return nil }
            return Candidate(
                state: .active(period: period, expiresAt: entitlement.expiresAt, willRenew: entitlement.willAutoRenew),
                end: entitlement.expiresAt, isGrace: false
            )
        case .gracePeriod:
            let end = entitlement.graceExpiresAt
            if let end, end <= now { return nil }
            return Candidate(state: .inGracePeriod(period: period, expiresAt: end), end: end, isGrace: true)
        case .billingRetry, .expired, .revoked:
            return nil
        }
    }
}
