//
//  EphemeralSubscriptionSnapshotStore.swift
//  BelloHub
//

#if DEBUG
import Foundation
import os

/// A snapshot store that forgets everything when the process ends, for UI-test launches and `#Preview` blocks: a test
/// launch must never read a plan an earlier launch left behind. DEBUG only.
final class EphemeralSubscriptionSnapshotStore: SubscriptionSnapshotStoring, Sendable {
    private let snapshot = OSAllocatedUnfairLock<SubscriptionSnapshot?>(initialState: nil)

    func load() -> SubscriptionSnapshot? {
        snapshot.withLock { $0 }
    }

    func save(_ snapshot: SubscriptionSnapshot) {
        self.snapshot.withLock { $0 = snapshot }
    }
}
#endif
