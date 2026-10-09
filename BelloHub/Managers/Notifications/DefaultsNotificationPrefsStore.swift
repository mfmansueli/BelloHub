//
//  DefaultsNotificationPrefsStore.swift
//  BelloHub
//

import Foundation

/// The choices as JSON in `UserDefaults`: they are switches, not client data, and the S6 scheduler on this iPhone is
/// what reads them. One key for all of them (`DefaultsKey.notificationPrefs`).
@MainActor
final class DefaultsNotificationPrefsStore: NotificationPrefsStoring {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> NotificationPrefs? {
        guard let data = defaults.data(forKey: DefaultsKey.notificationPrefs) else { return nil }
        return try? JSONDecoder().decode(NotificationPrefs.self, from: data)
    }

    func save(_ prefs: NotificationPrefs) throws {
        defaults.set(try JSONEncoder().encode(prefs), forKey: DefaultsKey.notificationPrefs)
    }
}
