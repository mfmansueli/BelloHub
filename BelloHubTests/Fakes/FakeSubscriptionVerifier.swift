//
//  FakeSubscriptionVerifier.swift
//  BelloHubTests
//

@testable import BelloHub
import os

/// A server that either echoes the store's state, overrides it, or cannot be reached.
final class FakeSubscriptionVerifier: SubscriptionVerifying, Sendable {
    private struct State {
        var override: SubscriptionState?
        var error: Error?
        var received: [SubscriptionState] = []
    }

    private let state: OSAllocatedUnfairLock<State>

    init(override: SubscriptionState? = nil, error: Error? = nil) {
        state = OSAllocatedUnfairLock(initialState: State(override: override, error: error))
    }

    var received: [SubscriptionState] { state.withLock { $0.received } }

    func verify(_ storeState: SubscriptionState) async throws -> SubscriptionState {
        try state.withLock { state in
            state.received.append(storeState)
            if let error = state.error { throw error }
            return state.override ?? storeState
        }
    }
}
