//
//  FixedNotificationPrefsStore.swift
//  BelloHubTests
//

@testable import BelloHub
import os

/// Notification prefs a test sets by hand.
final class FixedNotificationPrefsStore: NotificationPrefsStoring, Sendable {
    private let value: OSAllocatedUnfairLock<NotificationPrefs>

    init(_ prefs: NotificationPrefs = .standard) {
        value = OSAllocatedUnfairLock(initialState: prefs)
    }

    func load() -> NotificationPrefs { value.withLock { $0 } }

    func save(_ prefs: NotificationPrefs) { value.withLock { $0 = prefs } }
}
