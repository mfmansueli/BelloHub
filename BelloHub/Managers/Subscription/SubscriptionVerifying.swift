//
//  SubscriptionVerifying.swift
//  BelloHub
//

import Foundation

/// The verdict on her plan, decided on this iPhone (D59; it replaces the server verification of D33). The store's
/// verified entitlements go in; the plan state comes out and is kept as the offline snapshot. The app uses
/// `DeviceSubscriptionVerifier`; nothing about a purchase goes to our server.
protocol SubscriptionVerifying: Sendable {
    /// What the verified entitlements prove at `now`, saved as the last known state.
    func verify(_ entitlements: [StoreEntitlement], now: Date) async -> SubscriptionState
    /// The last proven state as it stands at `now` (offline, or before the store answers); nil when there is none.
    func cachedState(now: Date) async -> SubscriptionState?
}
