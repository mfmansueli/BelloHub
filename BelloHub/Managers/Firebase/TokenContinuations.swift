//
//  TokenContinuations.swift
//  BelloHub
//

import Foundation

/// The open token streams of `FirebaseMessagingManager`, behind a lock: the SDK calls its delegate on its own queue,
/// and a stream may be opened or closed from any task.
final class TokenContinuations: @unchecked Sendable {
    private let lock = NSLock()
    private var streams: [UUID: AsyncStream<String>.Continuation] = [:]

    func add(_ continuation: AsyncStream<String>.Continuation) -> UUID {
        let id = UUID()
        lock.withLock { streams[id] = continuation }
        return id
    }

    func remove(_ id: UUID) {
        lock.withLock { streams[id] = nil }
    }

    func yield(_ token: String) {
        let open = lock.withLock { Array(streams.values) }
        for continuation in open { continuation.yield(token) }
    }
}
