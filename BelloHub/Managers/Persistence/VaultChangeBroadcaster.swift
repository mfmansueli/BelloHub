//
//  VaultChangeBroadcaster.swift
//  BelloHub
//

import Foundation

import os

/// Tells observers that something changed, so `AsyncStream` lists reload. The streams are cold copies of a query,
/// not a database cursor: simple and correct for the few thousand records of one professional.
final class VaultChangeBroadcaster: Sendable {
    private let continuations = OSAllocatedUnfairLock(initialState: [UUID: AsyncStream<Void>.Continuation]())

    func notify() {
        continuations.withLock { $0.values.forEach { $0.yield() } }
    }

    private func subscribe() -> AsyncStream<Void> {
        AsyncStream { continuation in
            let token = UUID()
            continuations.withLock { $0[token] = continuation }
            continuation.onTermination = { [weak self] _ in
                _ = self?.continuations.withLock { $0.removeValue(forKey: token) }
            }
        }
    }

    /// `load` now, and again after every `notify()`.
    func stream<Value: Sendable>(_ load: @escaping @Sendable () async -> Value) -> AsyncStream<Value> {
        AsyncStream { continuation in
            // Subscribe before the first load so a change in between is not missed.
            let changes = subscribe()
            let task = Task {
                continuation.yield(await load())
                for await _ in changes {
                    continuation.yield(await load())
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
