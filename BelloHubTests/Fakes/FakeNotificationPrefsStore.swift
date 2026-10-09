//
//  FakeNotificationPrefsStore.swift
//  BelloHubTests
//

@testable import BelloHub
import os

/// Notification preferences held in memory, with a switch that makes every save fail.
final class FakeNotificationPrefsStore: NotificationPrefsStoring, Sendable {
    private struct State {
        var stored: NotificationPrefs?
        var failsSaves = false
        var saveCount = 0
    }

    private let state: OSAllocatedUnfairLock<State>

    init(stored: NotificationPrefs? = nil) {
        state = OSAllocatedUnfairLock(initialState: State(stored: stored))
    }

    var stored: NotificationPrefs? { state.withLock { $0.stored } }
    var saveCount: Int { state.withLock { $0.saveCount } }
    var failsSaves: Bool {
        get { state.withLock { $0.failsSaves } }
        set { state.withLock { $0.failsSaves = newValue } }
    }

    func load() -> NotificationPrefs {
        stored ?? .standard
    }

    func save(_ prefs: NotificationPrefs) throws {
        let fails = state.withLock { current -> Bool in
            current.saveCount += 1
            return current.failsSaves
        }
        if fails { throw FakeStoreError() }
        state.withLock { $0.stored = prefs }
    }
}
