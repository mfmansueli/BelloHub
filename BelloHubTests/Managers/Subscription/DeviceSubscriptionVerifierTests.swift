//
//  DeviceSubscriptionVerifierTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@Suite("DeviceSubscriptionVerifier")
struct DeviceSubscriptionVerifierTests {
    private let products = PlanProducts.fallback

    private func yearly(expires days: Int) -> StoreEntitlement {
        StoreEntitlement(productID: products.yearly, renewal: .subscribed, expiresAt: TestClock.days(days))
    }

    @Test("The verdict is saved as the offline snapshot and read back while the store is out of reach")
    func cachesTheVerdict() async {
        let store = FakeSubscriptionSnapshotStore()
        let verifier = DeviceSubscriptionVerifier(products: products, store: store)

        let state = await verifier.verify([yearly(expires: 30)], now: TestClock.now)

        #expect(state.hasActivePlan)
        #expect(store.snapshot?.accessEndsAt == TestClock.days(30))
        #expect(await verifier.cachedState(now: TestClock.days(5)) == state)
        #expect(await verifier.cachedState(now: TestClock.days(31)) == SubscriptionState.none)
    }

    @Test("No snapshot yet: nothing cached")
    func nothingCached() async {
        let verifier = DeviceSubscriptionVerifier(products: products, store: FakeSubscriptionSnapshotStore())
        #expect(await verifier.cachedState(now: TestClock.now) == nil)
    }

    @Test("A clock turned back after a later time was seen does not revive an expired plan")
    func clockTurnedBack() async {
        let store = FakeSubscriptionSnapshotStore()
        let verifier = DeviceSubscriptionVerifier(products: products, store: store)
        _ = await verifier.verify([yearly(expires: 30)], now: TestClock.now)
        _ = await verifier.cachedState(now: TestClock.days(40))

        // Back to today: the signed entitlement would still look valid against the wrong clock.
        #expect(await verifier.verify([yearly(expires: 30)], now: TestClock.now) == SubscriptionState.none)
        #expect(await verifier.cachedState(now: TestClock.now) == SubscriptionState.none)
    }

    @Test("A refund arriving later replaces the cached plan")
    func refundReplacesCache() async {
        let store = FakeSubscriptionSnapshotStore()
        let verifier = DeviceSubscriptionVerifier(products: products, store: store)
        _ = await verifier.verify([yearly(expires: 30)], now: TestClock.now)
        let refunded = StoreEntitlement(productID: products.yearly, renewal: .revoked, expiresAt: TestClock.days(30),
                                        revokedAt: TestClock.now)

        #expect(await verifier.verify([refunded], now: TestClock.days(1)) == SubscriptionState.none)
        #expect(await verifier.cachedState(now: TestClock.days(2)) == SubscriptionState.none)
    }
}
