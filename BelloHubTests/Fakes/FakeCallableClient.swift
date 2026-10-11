//
//  FakeCallableClient.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import os

/// The callable functions in a test: records each call (function and the JSON that would travel) and answers from a
/// table of canned `result` JSON, or throws a `ServerError`.
final class FakeCallableClient: CallableClient, Sendable {
    struct Call: Equatable {
        let function: String
        let body: Data

        /// The body as a dictionary, for assertions on keys.
        var object: [String: Any] {
            (try? JSONSerialization.jsonObject(with: body) as? [String: Any]) ?? [:]
        }
    }

    private struct State {
        var calls: [Call] = []
        var results: [String: String] = [:]
        var errors: [String: ServerError] = [:]
    }

    private let state = OSAllocatedUnfairLock(initialState: State())

    var calls: [Call] { state.withLock { $0.calls } }

    /// `json` is the `result` object the function answers with.
    func answer(_ function: String, with json: String) {
        state.withLock { $0.results[function] = json }
    }

    func fail(_ function: String, with error: ServerError) {
        state.withLock { $0.errors[function] = error }
    }

    func send(function: String, data: Data) async throws -> Data {
        try state.withLock { state in
            state.calls.append(Call(function: function, body: data))
            if let error = state.errors[function] { throw error }
            return Data((state.results[function] ?? "{}").utf8)
        }
    }
}
