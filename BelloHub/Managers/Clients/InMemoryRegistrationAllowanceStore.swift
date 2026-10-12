//
//  InMemoryRegistrationAllowanceStore.swift
//  BelloHub
//

import Foundation
import os

/// A count that lives as long as the process: UI-test launches and previews, where the vault ledger is the only count
/// that matters and a test must never read what an earlier launch left in the simulator's Keychain. The app passes
/// `KeychainRegistrationAllowanceStore`.
final class InMemoryRegistrationAllowanceStore: RegistrationAllowanceStoring, Sendable {
    private let count: OSAllocatedUnfairLock<Int?>

    init(count: Int? = nil) {
        self.count = OSAllocatedUnfairLock(initialState: count)
    }

    func load() -> Int? {
        count.withLock { $0 }
    }

    func save(_ count: Int) {
        self.count.withLock { $0 = count }
    }
}
