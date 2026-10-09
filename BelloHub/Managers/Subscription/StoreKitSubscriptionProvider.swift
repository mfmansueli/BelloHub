//
//  StoreKitSubscriptionProvider.swift
//  BelloHub
//

import StoreKit
import UIKit

/// StoreKit 2 as `SubscriptionProviding`: the only file that imports StoreKit. Prices are whatever the storefront
/// returns (`Product.displayPrice`, D33); the local `Config/BelloHub.storekit` file serves Xcode runs and tests.
struct StoreKitSubscriptionProvider: SubscriptionProviding {
    func offers() async throws -> [PlanOffer] {
        let products = try await Product.products(for: PlanProduct.allCases.map(\.rawValue))
        return products.compactMap { product in
            PlanPeriod(productID: product.id).map {
                PlanOffer(period: $0, displayPrice: product.displayPrice, price: product.price)
            }
        }
        .sorted { $0.period == .monthly && $1.period == .yearly }
    }

    func purchase(_ period: PlanPeriod) async throws -> PurchaseOutcome {
        guard let product = try await Product.products(for: [period.product.rawValue]).first else {
            throw SubscriptionError.productUnavailable
        }
        switch try await product.purchase() {
        case .success(let verification):
            let transaction = try Self.verified(verification)
            await transaction.finish()
            return .purchased
        case .userCancelled:
            return .cancelled
        case .pending:
            return .pending
        @unknown default:
            return .cancelled
        }
    }

    func restorePurchases() async throws -> PurchaseOutcome {
        try await AppStore.sync()
        return await currentState().hasActivePlan ? .purchased : .nothingToRestore
    }

    func currentState() async -> SubscriptionState {
        for await result in Transaction.currentEntitlements {
            guard let transaction = try? Self.verified(result),
                  let period = PlanPeriod(productID: transaction.productID) else { continue }
            let status = try? await transaction.subscriptionStatus
            let willRenew = (try? status?.renewalInfo.payloadValue.willAutoRenew) ?? true
            if status?.state == .inGracePeriod {
                return .inGracePeriod(period: period, expiresAt: transaction.expirationDate)
            }
            return .active(period: period, expiresAt: transaction.expirationDate, willRenew: willRenew)
        }
        return .none
    }

    func stateUpdates() -> AsyncStream<SubscriptionState> {
        AsyncStream { continuation in
            let task = Task {
                for await _ in Transaction.updates {
                    continuation.yield(await currentState())
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    @MainActor
    func showManageSubscriptions() async {
        guard let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first else {
            return
        }
        try? await AppStore.showManageSubscriptions(in: scene)
    }

    private static func verified<Value>(_ result: VerificationResult<Value>) throws -> Value {
        switch result {
        case .verified(let value): return value
        case .unverified: throw SubscriptionError.unverified
        }
    }
}
