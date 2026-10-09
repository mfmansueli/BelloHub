//
//  SubscriptionProviding.swift
//  BelloHub
//

/// The store behind a protocol (CLAUDE.md section 1: an SDK sits behind one Manager). StoreKit 2 implements it in
/// the app; tests and UI-test launches use a fake that never opens a payment sheet.
protocol SubscriptionProviding: Sendable {
    /// The two products with their storefront prices, monthly first.
    func offers() async throws -> [PlanOffer]
    /// Buys one period. Returns `.cancelled` when she dismissed the sheet, `.pending` when Apple asks someone first.
    func purchase(_ period: PlanPeriod) async throws -> PurchaseOutcome
    /// Asks the store for purchases made with her Apple ID on another device.
    func restorePurchases() async throws -> PurchaseOutcome
    /// Her current entitlement as the store knows it, now.
    func currentState() async -> SubscriptionState
    /// Every later change (a renewal, a refund, a purchase finished on another device).
    func stateUpdates() -> AsyncStream<SubscriptionState>
    /// Opens the system's "Manage subscription" sheet.
    func showManageSubscriptions() async
}
