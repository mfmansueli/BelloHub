//
//  FakeSubscriptionProvider.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import os

/// A store a test scripts: the offers it lists, what a purchase answers, the verified entitlements it reports (or that
/// it cannot be read), and what a restore brings back. `push()` fires the updates stream by hand.
final class FakeSubscriptionProvider: SubscriptionProviding, Sendable {
    private struct State {
        var offers: [PlanOffer]
        var offersError: Error?
        var entitlements: [StoreEntitlement]
        var entitlementsError: Error?
        var purchaseOutcome: PurchaseOutcome
        var purchaseError: Error?
        var restoreBrings: [StoreEntitlement]
        var purchases: [PlanPeriod] = []
        var syncCount = 0
        var manageCount = 0
    }

    static let products = PlanProducts.fallback

    private let state: OSAllocatedUnfairLock<State>
    private let stream: AsyncStream<Void>
    private let continuation: AsyncStream<Void>.Continuation

    static let standardOffers = [
        PlanOffer(period: .monthly, displayPrice: "€14.99", price: Decimal(string: "14.99") ?? 0),
        PlanOffer(period: .yearly, displayPrice: "€149.99", price: Decimal(string: "149.99") ?? 0)
    ]

    /// `state` is turned into the entitlement that proves it; `restoreOutcome == .purchased` makes a restore bring a
    /// yearly plan back.
    init(
        offers: [PlanOffer] = FakeSubscriptionProvider.standardOffers,
        state: SubscriptionState = .none,
        purchaseOutcome: PurchaseOutcome = .purchased,
        restoreOutcome: PurchaseOutcome = .nothingToRestore
    ) {
        let restored = restoreOutcome == .purchased
            ? [Self.entitlement(.active(period: .yearly, expiresAt: nil, willRenew: true))].compactMap { $0 } : []
        self.state = OSAllocatedUnfairLock(initialState: State(
            offers: offers, entitlements: [Self.entitlement(state)].compactMap { $0 },
            purchaseOutcome: purchaseOutcome, restoreBrings: restored
        ))
        // Made once, so an update pushed before the service subscribes is buffered, not lost.
        (stream, continuation) = AsyncStream.makeStream(of: Void.self)
    }

    /// The verified entitlement that proves `state`; nil for no plan.
    static func entitlement(_ state: SubscriptionState) -> StoreEntitlement? {
        switch state {
        case .unknown, .none: nil
        case .active(let period, let expiresAt, let willRenew):
            StoreEntitlement(productID: products.productID(for: period), renewal: .subscribed, expiresAt: expiresAt,
                             willAutoRenew: willRenew)
        case .inGracePeriod(let period, let expiresAt):
            StoreEntitlement(productID: products.productID(for: period), renewal: .gracePeriod, expiresAt: nil,
                             graceExpiresAt: expiresAt)
        }
    }

    var offersError: Error? {
        get { state.withLock { $0.offersError } }
        set { state.withLock { $0.offersError = newValue } }
    }

    var purchaseError: Error? {
        get { state.withLock { $0.purchaseError } }
        set { state.withLock { $0.purchaseError = newValue } }
    }

    /// What `entitlements()` answers next.
    var entitlementsNow: [StoreEntitlement] {
        get { state.withLock { $0.entitlements } }
        set { state.withLock { $0.entitlements = newValue } }
    }

    /// Set to make the store unreadable (offline, no storefront).
    var entitlementsError: Error? {
        get { state.withLock { $0.entitlementsError } }
        set { state.withLock { $0.entitlementsError = newValue } }
    }

    var purchases: [PlanPeriod] { state.withLock { $0.purchases } }
    var syncCount: Int { state.withLock { $0.syncCount } }
    var manageCount: Int { state.withLock { $0.manageCount } }

    /// A renewal or a refund arriving from the store while the app runs: the new entitlements, then the signal.
    func push(_ entitlements: [StoreEntitlement]) {
        state.withLock { $0.entitlements = entitlements }
        continuation.yield()
    }

    func offers() async throws -> [PlanOffer] {
        try state.withLock { state in
            if let error = state.offersError { throw error }
            return state.offers
        }
    }

    func purchase(_ period: PlanPeriod) async throws -> PurchaseOutcome {
        try state.withLock { state in
            state.purchases.append(period)
            if let error = state.purchaseError { throw error }
            if state.purchaseOutcome == .purchased {
                state.entitlements = [Self.entitlement(.active(period: period, expiresAt: nil, willRenew: true))]
                    .compactMap { $0 }
            }
            return state.purchaseOutcome
        }
    }

    func syncPurchases() async throws {
        state.withLock { state in
            state.syncCount += 1
            if !state.restoreBrings.isEmpty { state.entitlements = state.restoreBrings }
        }
    }

    func entitlements() async throws -> [StoreEntitlement] {
        try state.withLock { state in
            if let error = state.entitlementsError { throw error }
            return state.entitlements
        }
    }

    func updates() -> AsyncStream<Void> {
        stream
    }

    func showManageSubscriptions() async {
        state.withLock { $0.manageCount += 1 }
    }
}

struct FakeStoreError: Error {}
