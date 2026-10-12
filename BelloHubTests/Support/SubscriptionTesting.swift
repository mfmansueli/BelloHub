//
//  SubscriptionTesting.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation

/// A subscription service over a scripted store and the real on-device verifier (D59), with a snapshot kept in memory
/// and a fixed time.
@MainActor
func makeSubscriptionService(
    provider: FakeSubscriptionProvider = FakeSubscriptionProvider(),
    store: FakeSubscriptionSnapshotStore = FakeSubscriptionSnapshotStore(),
    now: Date = TestClock.now
) -> SubscriptionService {
    SubscriptionService(
        provider: provider,
        verifier: DeviceSubscriptionVerifier(products: FakeSubscriptionProvider.products, store: store),
        now: { now }
    )
}
