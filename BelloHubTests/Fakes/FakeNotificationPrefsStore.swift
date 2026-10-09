//
//  FakeNotificationPrefsStore.swift
//  BelloHubTests
//

@testable import BelloHub

/// Notification preferences held in memory, with a switch that makes every save fail.
@MainActor
final class FakeNotificationPrefsStore: NotificationPrefsStoring {
    private(set) var stored: NotificationPrefs?
    var failsSaves = false
    private(set) var saveCount = 0

    init(stored: NotificationPrefs? = nil) {
        self.stored = stored
    }

    func load() -> NotificationPrefs? {
        stored
    }

    func save(_ prefs: NotificationPrefs) throws {
        saveCount += 1
        if failsSaves { throw FakeStoreError() }
        stored = prefs
    }
}
