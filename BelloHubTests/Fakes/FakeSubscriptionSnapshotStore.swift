//
//  FakeSubscriptionSnapshotStore.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import os

/// The offline snapshot kept in memory, readable by the test.
final class FakeSubscriptionSnapshotStore: SubscriptionSnapshotStoring, Sendable {
    private let stored: OSAllocatedUnfairLock<SubscriptionSnapshot?>

    init(_ snapshot: SubscriptionSnapshot? = nil) {
        stored = OSAllocatedUnfairLock(initialState: snapshot)
    }

    var snapshot: SubscriptionSnapshot? { stored.withLock { $0 } }

    func load() -> SubscriptionSnapshot? {
        stored.withLock { $0 }
    }

    func save(_ snapshot: SubscriptionSnapshot) {
        stored.withLock { $0 = snapshot }
    }
}
