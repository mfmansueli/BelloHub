//
//  FakeAccountDeleter.swift
//  BelloHubTests
//

@testable import BelloHub
import os

/// A server that answers deletions from a script and remembers every request, so a test can check the Apple code
/// travelled and that nothing local was touched before the answer.
final class FakeAccountDeleter: AccountDeleting, Sendable {
    private struct State {
        var outcome: AccountDeletionOutcome
        var error: Error?
        var requests: [AccountDeletionRequest] = []
    }

    private let state: OSAllocatedUnfairLock<State>

    init(outcome: AccountDeletionOutcome = .deleted, error: Error? = nil) {
        state = OSAllocatedUnfairLock(initialState: State(outcome: outcome, error: error))
    }

    var requests: [AccountDeletionRequest] { state.withLock { $0.requests } }

    func deleteAccount(_ request: AccountDeletionRequest) async throws -> AccountDeletionOutcome {
        try state.withLock { state in
            state.requests.append(request)
            if let error = state.error { throw error }
            return state.outcome
        }
    }
}

struct FakeServerError: Error {}
