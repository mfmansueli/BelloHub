//
//  FakePushTokenProvider.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import os

/// FCM in a test: the token stream is fed by hand with `send(_:)` (a first token, then refreshes), and the calls the
/// app makes to the system are counted.
final class FakePushTokenProvider: PushTokenProviding, Sendable {
    private struct State {
        var registerCount = 0
        var apnsTokens: [Data] = []
    }

    private let state = OSAllocatedUnfairLock(initialState: State())
    private let stream: AsyncStream<String>
    private let continuation: AsyncStream<String>.Continuation

    init() {
        // Made once, so a token sent before the service subscribes is buffered, not lost.
        (stream, continuation) = AsyncStream.makeStream(of: String.self)
    }

    var registerCount: Int { state.withLock { $0.registerCount } }

    /// FCM issued (or refreshed) a token.
    func send(_ token: String) {
        continuation.yield(token)
    }

    func tokens() -> AsyncStream<String> {
        stream
    }

    func setAPNSToken(_ deviceToken: Data) {
        state.withLock { $0.apnsTokens.append(deviceToken) }
    }

    @MainActor
    func registerForRemoteNotifications() {
        state.withLock { $0.registerCount += 1 }
    }
}
