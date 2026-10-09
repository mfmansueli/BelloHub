//
//  DefaultsNotificationPrefsStore.swift
//  BelloHub
//

import Foundation

/// The prefs as JSON in `UserDefaults`: they hold switches and times, never a name or clinical data, so the vault is
/// not needed. One key for all of them (`DefaultsKey.notificationPrefs`); a missing or unreadable value is
/// `NotificationPrefs.standard`. `@unchecked Sendable` because `UserDefaults` is documented as thread-safe but the
/// SDK does not mark it `Sendable`; remove when it does.
struct DefaultsNotificationPrefsStore: NotificationPrefsStoring, @unchecked Sendable {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> NotificationPrefs {
        guard let data = defaults.data(forKey: DefaultsKey.notificationPrefs),
              let prefs = try? JSONDecoder().decode(NotificationPrefs.self, from: data) else { return .standard }
        return prefs
    }

    func save(_ prefs: NotificationPrefs) throws {
        defaults.set(try JSONEncoder().encode(prefs), forKey: DefaultsKey.notificationPrefs)
    }
}
