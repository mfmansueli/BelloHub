//
//  FakePushTokenProvider.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import os

/// FCM in a test: tokens are fed by hand with `send(_:)` (a first token, then refreshes), and the calls the app makes
/// to the system are counted. Like the real provider, every `tokens()` stream starts with the current token, so a
/// listener that subscribes late (a relaunch) still learns it.
final class FakePushTokenProvider: PushTokenProviding, Sendable {
    private struct State {
        var registerCount = 0
        var current: String?
        var listeners: [UUID: AsyncStream<String>.Continuation] = [:]
    }

    private let state = OSAllocatedUnfairLock(initialState: State())

    var registerCount: Int { state.withLock { $0.registerCount } }

    /// FCM issued (or refreshed) a token.
    func send(_ token: String) {
        let listeners = state.withLock { state in
            state.current = token
            return Array(state.listeners.values)
        }
        for listener in listeners { listener.yield(token) }
    }

    func tokens() -> AsyncStream<String> {
        let (stream, continuation) = AsyncStream.makeStream(of: String.self)
        let id = UUID()
        let current = state.withLock { state in
            state.listeners[id] = continuation
            return state.current
        }
        continuation.onTermination = { [weak self] _ in
            self?.state.withLock { _ = $0.listeners.removeValue(forKey: id) }
        }
        if let current { continuation.yield(current) }
        return stream
    }

    func setAPNSToken(_ deviceToken: Data) {}

    @MainActor
    func registerForRemoteNotifications() {
        state.withLock { $0.registerCount += 1 }
    }
}
