//
//  IDCounter.swift
//  BelloHubTests
//

import Foundation

/// Hands out a fixed list of ids one by one, then fresh ones, so a test can know the id a ViewModel will use. Safe to
/// capture in a `@Sendable` closure.
final class IDCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var remaining: [UUID]

    init(_ ids: [UUID]) {
        remaining = ids
    }

    func next() -> UUID {
        lock.lock()
        defer { lock.unlock() }
        return remaining.isEmpty ? UUID() : remaining.removeFirst()
    }
}
