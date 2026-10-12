//
//  DeviceSubscriptionVerifier.swift
//  BelloHub
//

import Foundation

/// The plan decided on this iPhone (D59): `EntitlementRules` over the store's verified entitlements, measured against
/// the latest time this iPhone has shown (so a clock turned back never stretches a plan), and kept as a
/// `SubscriptionSnapshot` for offline use. No server, no account token.
struct DeviceSubscriptionVerifier: SubscriptionVerifying {
    private let products: PlanProducts
    private let store: any SubscriptionSnapshotStoring

    init(products: PlanProducts = .current, store: any SubscriptionSnapshotStoring) {
        self.products = products
        self.store = store
    }

    func verify(_ entitlements: [StoreEntitlement], now: Date) async -> SubscriptionState {
        let effectiveNow = max(now, store.load()?.latestSeenAt ?? now)
        let state = EntitlementRules.state(from: entitlements, products: products, now: effectiveNow)
        store.save(SubscriptionSnapshot(state: state, seenAt: effectiveNow))
        return state
    }

    func cachedState(now: Date) async -> SubscriptionState? {
        guard let snapshot = store.load()?.seen(at: now) else { return nil }
        store.save(snapshot)
        return snapshot.state(at: now)
    }
}
