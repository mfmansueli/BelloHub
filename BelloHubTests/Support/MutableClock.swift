//
//  MutableClock.swift
//  BelloHubTests
//

import Foundation
import os

/// A clock the test moves by hand, so lock and ledger behavior is tested at exact instants.
final class MutableClock: Sendable {
    private let current: OSAllocatedUnfairLock<Date>

    init(_ start: Date = TestClock.now) {
        current = OSAllocatedUnfairLock(initialState: start)
    }

    var now: Date {
        current.withLock { $0 }
    }

    func advance(by interval: TimeInterval) {
        current.withLock { $0 = $0.addingTimeInterval(interval) }
    }

    func set(_ date: Date) {
        current.withLock { $0 = date }
    }
}
