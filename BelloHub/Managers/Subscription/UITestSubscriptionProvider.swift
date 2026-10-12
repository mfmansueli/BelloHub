//
//  UITestSubscriptionProvider.swift
//  BelloHub
//

#if DEBUG
import Foundation
import os

/// A store that answers the way a UI test tells it to (`-uiPlan none|active`), with prices written for the launch
/// locale, because a UI test cannot drive the App Store sheet. It reports its plan as a verified entitlement a year
/// long, so the on-device verifier decides as it does in the app. DEBUG only: a Release build only talks to StoreKit.
final class UITestSubscriptionProvider: SubscriptionProviding, Sendable {
    private let plan: OSAllocatedUnfairLock<PlanPeriod?>
    private let products: PlanProducts
    private let locale: Locale

    init(hasPlan: Bool, products: PlanProducts = .current, locale: Locale = .current) {
        plan = OSAllocatedUnfairLock(initialState: hasPlan ? .yearly : nil)
        self.products = products
        self.locale = locale
    }

    func offers() async throws -> [PlanOffer] {
        let style = Decimal.FormatStyle.Currency(code: "EUR").locale(locale)
        return [
            PlanOffer(period: .monthly, displayPrice: Decimal(string: "14.99")?.formatted(style) ?? "", price: 14.99),
            PlanOffer(period: .yearly, displayPrice: Decimal(string: "149.99")?.formatted(style) ?? "", price: 149.99)
        ]
    }

    func purchase(_ period: PlanPeriod) async throws -> PurchaseOutcome {
        plan.withLock { $0 = period }
        return .purchased
    }

    func syncPurchases() async throws {}

    func entitlements() async throws -> [StoreEntitlement] {
        guard let period = plan.withLock({ $0 }) else { return [] }
        return [StoreEntitlement(
            productID: products.productID(for: period), renewal: .subscribed,
            expiresAt: Date().addingTimeInterval(365 * 86_400)
        )]
    }

    func updates() -> AsyncStream<Void> {
        AsyncStream { $0.finish() }
    }

    func showManageSubscriptions() async {}
}
#endif
