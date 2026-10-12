//
//  StoreKitSubscriptionProvider.swift
//  BelloHub
//

import os
import StoreKit
import UIKit

/// StoreKit 2 as `SubscriptionProviding`: the only file that imports StoreKit (D59). Prices are whatever the storefront
/// returns (`Product.displayPrice`, D33); the local `Config/BelloHub.storekit` file serves Xcode runs and tests.
///
/// Only transactions StoreKit verified against Apple's signature (`VerificationResult.verified`) leave this file. An
/// unverified one is ignored and logged by product id only (no personal data). The subscription's state comes from
/// `Product.SubscriptionInfo.status` (subscribed, expired, billing retry, grace period, revoked) with the signed
/// renewal info; when that cannot be read (offline), the locally signed `Transaction.currentEntitlements` stand in.
struct StoreKitSubscriptionProvider: SubscriptionProviding {
    private let products: PlanProducts
    private let logger = Logger(subsystem: "app.bellohub", category: "store")

    init(products: PlanProducts = .current) {
        self.products = products
    }

    func offers() async throws -> [PlanOffer] {
        try await StoreKit.Product.products(for: products.all)
            .compactMap { product in
                products.period(forProductID: product.id).map {
                    PlanOffer(period: $0, displayPrice: product.displayPrice, price: product.price)
                }
            }
            .sorted { $0.period == .monthly && $1.period == .yearly }
    }

    func purchase(_ period: PlanPeriod) async throws -> PurchaseOutcome {
        guard let product = try await StoreKit.Product.products(for: [products.productID(for: period)]).first else {
            throw SubscriptionError.productUnavailable
        }
        switch try await product.purchase() {
        case .success(let verification):
            guard case .verified(let transaction) = verification else {
                logUnverified(productID: product.id)
                throw SubscriptionError.unverified
            }
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

    func syncPurchases() async throws {
        try await AppStore.sync()
    }

    func entitlements() async throws -> [StoreEntitlement] {
        if let fromStatus = try? await statusEntitlements() { return fromStatus }
        return await localEntitlements()
    }

    func updates() -> AsyncStream<Void> {
        let logger = logger
        return AsyncStream { continuation in
            let task = Task {
                for await result in Transaction.updates {
                    switch result {
                    case .verified(let transaction): await transaction.finish()
                    case .unverified(let transaction, _):
                        logger.error("unverified update ignored product=\(transaction.productID, privacy: .public)")
                    }
                    continuation.yield()
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

    // MARK: - Private

    /// The group's statuses (one per subscription the Apple ID has had in the group), with signed renewal info.
    private func statusEntitlements() async throws -> [StoreEntitlement] {
        guard let subscription = try await StoreKit.Product.products(for: products.all).first?.subscription else {
            throw SubscriptionError.productUnavailable
        }
        return try await subscription.status.compactMap { status -> StoreEntitlement? in
            guard case .verified(let transaction) = status.transaction else {
                logUnverified(productID: nil)
                return nil
            }
            let renewal: StoreKit.Product.SubscriptionInfo.RenewalInfo? = switch status.renewalInfo {
            case .verified(let info): info
            case .unverified: nil
            }
            return StoreEntitlement(
                productID: transaction.productID, renewal: Self.renewal(status.state),
                expiresAt: transaction.expirationDate, revokedAt: transaction.revocationDate,
                graceExpiresAt: renewal?.gracePeriodExpirationDate, willAutoRenew: renewal?.willAutoRenew ?? true
            )
        }
    }

    /// Offline: the transactions StoreKit keeps signed on the device. They carry no renewal state, so a transaction
    /// past its expiry reads as expired.
    private func localEntitlements() async -> [StoreEntitlement] {
        var found: [StoreEntitlement] = []
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else {
                logUnverified(productID: nil)
                continue
            }
            guard products.period(forProductID: transaction.productID) != nil else { continue }
            let isPast = transaction.expirationDate.map { $0 <= Date() } ?? false
            found.append(StoreEntitlement(
                productID: transaction.productID, renewal: isPast ? .expired : .subscribed,
                expiresAt: transaction.expirationDate, revokedAt: transaction.revocationDate
            ))
        }
        return found
    }

    private static func renewal(_ state: StoreKit.Product.SubscriptionInfo.RenewalState) -> StoreEntitlement.Renewal {
        switch state {
        case .subscribed: .subscribed
        case .inGracePeriod: .gracePeriod
        case .inBillingRetryPeriod: .billingRetry
        case .revoked: .revoked
        default: .expired
        }
    }

    private func logUnverified(productID: String?) {
        logger.error("unverified transaction ignored product=\(productID ?? "unknown", privacy: .public)")
    }
}
