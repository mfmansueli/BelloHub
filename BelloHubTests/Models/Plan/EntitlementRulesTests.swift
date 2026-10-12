//
//  EntitlementRulesTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@Suite("EntitlementRules")
struct EntitlementRulesTests {
    private let products = PlanProducts.fallback
    private let now = TestClock.now

    private func state(_ entitlements: [StoreEntitlement]) -> SubscriptionState {
        EntitlementRules.state(from: entitlements, products: products, now: now)
    }

    private func entitlement(
        _ period: PlanPeriod = .monthly, _ renewal: StoreEntitlement.Renewal = .subscribed, expires days: Int? = 10,
        revoked: Bool = false, grace graceDays: Int? = nil, renews: Bool = true
    ) -> StoreEntitlement {
        StoreEntitlement(
            productID: products.productID(for: period), renewal: renewal, expiresAt: days.map { TestClock.days($0) },
            revokedAt: revoked ? TestClock.days(-1) : nil, graceExpiresAt: graceDays.map { TestClock.days($0) },
            willAutoRenew: renews
        )
    }

    @Test("A subscribed plan is active until its signed expiry, with the renewal flag")
    func active() {
        #expect(state([entitlement(.yearly, renews: false)])
            == .active(period: .yearly, expiresAt: TestClock.days(10), willRenew: false))
        #expect(state([entitlement(expires: -1)]) == .none, "past its signed expiry")
        #expect(state([]) == .none)
    }

    @Test("A refund or a revocation wins over everything")
    func revoked() {
        #expect(state([entitlement(revoked: true)]) == .none)
        #expect(state([entitlement(.monthly, .revoked)]) == .none)
        #expect(state([entitlement(.monthly, .gracePeriod, expires: -2, revoked: true, grace: 5)]) == .none)
    }

    @Test("The grace period keeps the plan until its signed end; billing retry without grace and expired do not")
    func graceAndRetry() {
        #expect(state([entitlement(.monthly, .gracePeriod, expires: -2, grace: 5)])
            == .inGracePeriod(period: .monthly, expiresAt: TestClock.days(5)))
        #expect(state([entitlement(.monthly, .gracePeriod, expires: -20, grace: -1)]) == .none, "grace over")
        #expect(state([entitlement(.monthly, .billingRetry, expires: -2)]) == .none)
        #expect(state([entitlement(.monthly, .expired, expires: -2)]) == .none)
    }

    @Test("Other apps' or unknown products are ignored; an active plan wins over grace, then the longer one")
    func choice() {
        let foreign = StoreEntitlement(productID: "com.other.pro", renewal: .subscribed, expiresAt: TestClock.days(30))
        #expect(state([foreign]) == .none)
        #expect(state([entitlement(.monthly, .gracePeriod, expires: -1, grace: 30), entitlement(.yearly, expires: 3)])
            .period == .yearly)
        #expect(state([entitlement(.monthly, expires: 3), entitlement(.yearly, expires: 300)])
            == .active(period: .yearly, expiresAt: TestClock.days(300), willRenew: true))
    }
}
