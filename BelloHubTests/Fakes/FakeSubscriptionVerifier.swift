//
//  FakeSubscriptionVerifier.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import os

/// A server that either echoes the store's state, overrides it, or cannot be reached; and hands out an account token
/// for purchases (or fails to).
final class FakeSubscriptionVerifier: SubscriptionVerifying, Sendable {
    private struct State {
        var override: SubscriptionState?
        var error: Error?
        var token: UUID?
        var tokenError: Error?
        var received: [SubscriptionState] = []
        var signedTransactions: [String?] = []
    }

    private let state: OSAllocatedUnfairLock<State>

    init(override: SubscriptionState? = nil, error: Error? = nil, token: UUID? = nil, tokenError: Error? = nil) {
        state = OSAllocatedUnfairLock(
            initialState: State(override: override, error: error, token: token, tokenError: tokenError)
        )
    }

    var received: [SubscriptionState] { state.withLock { $0.received } }
    /// The JWS that came with each `verify`, in order.
    var signedTransactions: [String?] { state.withLock { $0.signedTransactions } }

    func purchaseToken() async throws -> UUID? {
        try state.withLock { state in
            if let error = state.tokenError { throw error }
            return state.token
        }
    }

    func verify(_ storeState: SubscriptionState, signedTransaction: String?) async throws -> SubscriptionState {
        try state.withLock { state in
            state.received.append(storeState)
            state.signedTransactions.append(signedTransaction)
            if let error = state.error { throw error }
            return state.override ?? storeState
        }
    }
}
