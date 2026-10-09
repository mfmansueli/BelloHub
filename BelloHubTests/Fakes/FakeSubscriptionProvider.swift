//
//  FakeSubscriptionProvider.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import os

/// A store a test scripts: the offers it lists, what a purchase and a restore answer, and the state it reports.
/// The updates stream is fed by hand with `push(_:)`.
final class FakeSubscriptionProvider: SubscriptionProviding, Sendable {
    private struct State {
        var offers: [PlanOffer]
        var offersError: Error?
        var state: SubscriptionState
        var purchaseOutcome: PurchaseOutcome
        var purchaseError: Error?
        var restoreOutcome: PurchaseOutcome
        var purchases: [PlanPeriod] = []
        var restoreCount = 0
        var manageCount = 0
    }

    private let state: OSAllocatedUnfairLock<State>
    private let stream: AsyncStream<SubscriptionState>
    private let continuation: AsyncStream<SubscriptionState>.Continuation

    static let standardOffers = [
        PlanOffer(period: .monthly, displayPrice: "€14.99", price: Decimal(string: "14.99") ?? 0),
        PlanOffer(period: .yearly, displayPrice: "€149.99", price: Decimal(string: "149.99") ?? 0)
    ]

    init(
        offers: [PlanOffer] = FakeSubscriptionProvider.standardOffers,
        state: SubscriptionState = .none,
        purchaseOutcome: PurchaseOutcome = .purchased,
        restoreOutcome: PurchaseOutcome = .nothingToRestore
    ) {
        self.state = OSAllocatedUnfairLock(initialState: State(
            offers: offers, state: state, purchaseOutcome: purchaseOutcome, restoreOutcome: restoreOutcome
        ))
        // Made once, so an update pushed before the service subscribes is buffered, not lost.
        (stream, continuation) = AsyncStream.makeStream(of: SubscriptionState.self)
    }

    var offersError: Error? {
        get { state.withLock { $0.offersError } }
        set { state.withLock { $0.offersError = newValue } }
    }

    var purchaseError: Error? {
        get { state.withLock { $0.purchaseError } }
        set { state.withLock { $0.purchaseError = newValue } }
    }

    var purchases: [PlanPeriod] { state.withLock { $0.purchases } }
    var restoreCount: Int { state.withLock { $0.restoreCount } }
    var manageCount: Int { state.withLock { $0.manageCount } }

    /// A renewal or a refund arriving from the store while the app runs.
    func push(_ update: SubscriptionState) {
        state.withLock { $0.state = update }
        continuation.yield(update)
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
                state.state = .active(period: period, expiresAt: nil, willRenew: true)
            }
            return state.purchaseOutcome
        }
    }

    func restorePurchases() async throws -> PurchaseOutcome {
        state.withLock { state in
            state.restoreCount += 1
            if state.restoreOutcome == .purchased, !state.state.hasActivePlan {
                state.state = .active(period: .yearly, expiresAt: nil, willRenew: true)
            }
            return state.restoreOutcome
        }
    }

    func currentState() async -> SubscriptionState {
        state.withLock { $0.state }
    }

    func stateUpdates() -> AsyncStream<SubscriptionState> {
        stream
    }

    func showManageSubscriptions() async {
        state.withLock { $0.manageCount += 1 }
    }
}

struct FakeStoreError: Error {}
