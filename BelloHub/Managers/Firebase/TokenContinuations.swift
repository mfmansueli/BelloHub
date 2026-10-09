//
//  TokenContinuations.swift
//  BelloHub
//

import Foundation

/// The open token streams of `FirebaseMessagingManager`, behind a lock: the SDK calls its delegate on its own queue,
/// and a stream may be opened or closed from any task. The last token is kept so a stream opened after the delegate
/// fired still starts with it (the SDK's synchronous `fcmToken` getter is deprecated in Firebase 13).
final class TokenContinuations: @unchecked Sendable {
    private let lock = NSLock()
    private var streams: [UUID: AsyncStream<String>.Continuation] = [:]
    private var last: String?

    func add(_ continuation: AsyncStream<String>.Continuation) -> UUID {
        let id = UUID()
        let current = lock.withLock {
            streams[id] = continuation
            return last
        }
        if let current { continuation.yield(current) }
        return id
    }

    func remove(_ id: UUID) {
        lock.withLock { streams[id] = nil }
    }

    func yield(_ token: String) {
        let open = lock.withLock {
            last = token
            return Array(streams.values)
        }
        for continuation in open { continuation.yield(token) }
    }
}
