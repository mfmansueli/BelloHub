//
//  SubscriptionProviding.swift
//  BelloHub
//

import Foundation

/// The store behind a protocol (CLAUDE.md section 1: an SDK sits behind one Manager). StoreKit 2 implements it in
/// the app; tests and UI-test launches use a fake that never opens a payment sheet. It hands on only what Apple's
/// signature proved (`StoreEntitlement`); deciding what that means is `DeviceSubscriptionVerifier`'s job.
protocol SubscriptionProviding: Sendable {
    /// The two products with their storefront prices, monthly first.
    func offers() async throws -> [PlanOffer]
    /// Buys one period. Returns `.cancelled` when she dismissed the sheet, `.pending` when Apple asks someone first.
    /// A transaction whose signature does not check out throws `SubscriptionError.unverified`.
    func purchase(_ period: PlanPeriod) async throws -> PurchaseOutcome
    /// "Restore purchases" (App Review): asks the App Store to sync her purchases (`AppStore.sync()`).
    func syncPurchases() async throws
    /// The plan's subscriptions as Apple signed them, verified only. Throws when the store cannot be read at all.
    func entitlements() async throws -> [StoreEntitlement]
    /// Fires on every later change (a renewal, a refund, a purchase finished on another device).
    func updates() -> AsyncStream<Void>
    /// Opens the system's "Manage subscription" sheet.
    func showManageSubscriptions() async
}
