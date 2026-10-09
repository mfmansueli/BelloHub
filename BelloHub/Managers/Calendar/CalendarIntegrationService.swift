//
//  CalendarIntegrationService.swift
//  BelloHub
//

import Foundation
import Observation

/// Apple Calendar on and off (7.6). "Connected" means she switched it on **and** the iPhone allows writing; the
/// switch is remembered in `UserDefaults` (a preference, not client data). The write-through of appointments is S6's.
@MainActor
@Observable
final class CalendarIntegrationService {
    private(set) var access: CalendarAccessStatus
    private(set) var isEnabled: Bool

    private let provider: any CalendarAccessProviding
    private let defaults: UserDefaults

    init(provider: any CalendarAccessProviding = EventKitCalendarAccess(), defaults: UserDefaults = .standard) {
        self.provider = provider
        self.defaults = defaults
        access = provider.status()
        isEnabled = defaults.bool(forKey: DefaultsKey.appleCalendarEnabled)
    }

    var isConnected: Bool { isEnabled && access.canWrite }

    func refresh() {
        access = provider.status()
    }

    /// Switches the sync on: asks the iPhone first when it never did. Returns whether it is connected afterwards.
    @discardableResult
    func connect() async -> Bool {
        if access == .notDetermined { access = await provider.requestFullAccess() }
        guard access.canWrite else {
            isEnabled = false
            return false
        }
        isEnabled = true
        defaults.set(true, forKey: DefaultsKey.appleCalendarEnabled)
        return true
    }

    func disconnect() {
        isEnabled = false
        defaults.set(false, forKey: DefaultsKey.appleCalendarEnabled)
    }
}
