//
//  UITestSubscriptionProvider.swift
//  BelloHub
//

#if DEBUG
import Foundation
import os

/// A store that answers the way a UI test tells it to (`-uiPlan none|active`), with prices written for the launch
/// locale, because a UI test cannot drive the App Store sheet. DEBUG only: a Release build only talks to StoreKit.
final class UITestSubscriptionProvider: SubscriptionProviding, Sendable {
    private let state: OSAllocatedUnfairLock<SubscriptionState>
    private let locale: Locale

    init(hasPlan: Bool, locale: Locale = .current) {
        state = OSAllocatedUnfairLock(
            initialState: hasPlan ? .active(period: .yearly, expiresAt: nil, willRenew: true) : .none
        )
        self.locale = locale
    }

    func offers() async throws -> [PlanOffer] {
        let style = Decimal.FormatStyle.Currency(code: "EUR").locale(locale)
        return [
            PlanOffer(period: .monthly, displayPrice: Decimal(string: "14.99")?.formatted(style) ?? "", price: 14.99),
            PlanOffer(period: .yearly, displayPrice: Decimal(string: "149.99")?.formatted(style) ?? "", price: 149.99)
        ]
    }

    func purchase(_ period: PlanPeriod, appAccountToken: UUID?) async throws -> PurchaseOutcome {
        state.withLock { $0 = .active(period: period, expiresAt: nil, willRenew: true) }
        return .purchased
    }

    func restorePurchases() async throws -> PurchaseOutcome {
        state.withLock { $0 }.hasActivePlan ? .purchased : .nothingToRestore
    }

    func currentState() async -> SubscriptionState {
        state.withLock { $0 }
    }

    /// No signed transaction: there is no server to show it to.
    func currentSignedTransaction() async -> String? {
        nil
    }

    func stateUpdates() -> AsyncStream<SubscriptionState> {
        AsyncStream { $0.finish() }
    }

    func showManageSubscriptions() async {}
}
#endif
