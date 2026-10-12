//
//  FakeRegistrationAllowanceStore.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import os

/// The Keychain allowance in memory, readable by the test; `isBroken` makes every read answer nothing and every write
/// fail silently, as a locked or damaged Keychain would.
final class FakeRegistrationAllowanceStore: RegistrationAllowanceStoring, Sendable {
    private struct State {
        var count: Int?
        var isBroken = false
        var saves = 0
    }

    private let state: OSAllocatedUnfairLock<State>

    init(count: Int? = nil) {
        state = OSAllocatedUnfairLock(initialState: State(count: count))
    }

    var count: Int? { state.withLock { $0.count } }
    var saves: Int { state.withLock { $0.saves } }

    var isBroken: Bool {
        get { state.withLock { $0.isBroken } }
        set { state.withLock { $0.isBroken = newValue } }
    }

    func load() -> Int? {
        state.withLock { $0.isBroken ? nil : $0.count }
    }

    func save(_ count: Int) {
        state.withLock { state in
            guard !state.isBroken else { return }
            state.count = count
            state.saves += 1
        }
    }
}
