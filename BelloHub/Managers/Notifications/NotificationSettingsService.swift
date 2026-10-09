//
//  NotificationSettingsService.swift
//  BelloHub
//

import Foundation
import Observation

/// Her notification choices (7.4) and the system permission behind them, shared so the settings screen and, in S6,
/// the local scheduler read the same values. The scheduling itself is not here (S6 "home" owns it): this is the
/// model and the permission flow only. The published value changes only after the store confirmed the write.
@MainActor
@Observable
final class NotificationSettingsService {
    private(set) var prefs: NotificationPrefs
    private(set) var hideNamesOnLockScreen: Bool

    private let store: any NotificationPrefsStoring
    private let permissions: PermissionService
    private let defaults: UserDefaults

    /// `store` defaults to the JSON store in the same `defaults` suite, so a UI-test launch (its own suite, wiped at
    /// every start) and the account deletion (which clears that suite) never see another run's switches.
    init(
        store: (any NotificationPrefsStoring)? = nil,
        permissions: PermissionService,
        defaults: UserDefaults = .standard
    ) {
        self.store = store ?? DefaultsNotificationPrefsStore(defaults: defaults)
        self.permissions = permissions
        self.defaults = defaults
        prefs = self.store.load()
        hideNamesOnLockScreen = defaults.object(forKey: DefaultsKey.hideNamesOnLockScreen) as? Bool ?? true
    }

    // MARK: - Permission

    var permissionStatus: PermissionStatus { permissions.status(of: .notifications) }

    func refreshPermission() async {
        await permissions.refresh()
    }

    /// Shows the system dialog once; afterwards the only way is Settings.
    @discardableResult
    func requestPermission() async -> PermissionStatus {
        await permissions.request(.notifications)
    }

    // MARK: - Preferences

    func save(_ updated: NotificationPrefs) throws {
        try store.save(updated)
        prefs = updated
    }

    /// Privacy and security's switch: notifications say "A client" instead of a name (docs/06 section 4.4).
    func setHideNamesOnLockScreen(_ value: Bool) {
        defaults.set(value, forKey: DefaultsKey.hideNamesOnLockScreen)
        hideNamesOnLockScreen = value
    }
}
