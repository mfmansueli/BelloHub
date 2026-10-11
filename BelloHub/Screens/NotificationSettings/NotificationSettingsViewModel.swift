//
//  NotificationSettingsViewModel.swift
//  BelloHub
//

import Foundation
import Observation

/// State and actions of Notification settings (7.4). Every switch saves as she taps it; the permission flow asks the
/// system once and then points to Settings.
@MainActor
@Observable
final class NotificationSettingsViewModel {
    private(set) var errorMessage: String?
    private(set) var isAsking = false

    private let service: NotificationSettingsService
    private let settings: any SettingsOpening
    let calendar: Calendar

    init(
        service: NotificationSettingsService, settings: any SettingsOpening = SystemSettingsOpener(),
        calendar: Calendar = .current
    ) {
        self.service = service
        self.settings = settings
        self.calendar = calendar
    }

    // MARK: - Reading

    var prefs: NotificationPrefs { service.prefs }
    var permission: NotificationSettingsRules.PermissionNotice {
        NotificationSettingsRules.notice(for: service.permissionStatus)
    }
    var quietHoursOn: Bool { prefs.quietHours != nil }
    var quietFrom: Date {
        NotificationSettingsRules.date(forMinutes: prefs.quietHours?.fromMinutes ?? 0, calendar: calendar)
    }
    var quietUntil: Date {
        NotificationSettingsRules.date(forMinutes: prefs.quietHours?.untilMinutes ?? 0, calendar: calendar)
    }
    var reminderTime: Date {
        NotificationSettingsRules.date(forMinutes: prefs.reminderTimeMinutes, calendar: calendar)
    }

    // MARK: - Permission

    func refresh() async {
        await service.refreshPermission()
    }

    func askPermission() {
        Task { await askPermissionAsync() }
    }

    func askPermissionAsync() async {
        guard !isAsking else { return }
        isAsking = true
        defer { isAsking = false }
        await service.requestPermission()
    }

    func openSettings() {
        settings.openSettings()
    }

    // MARK: - Switches

    func update(_ change: (inout NotificationPrefs) -> Void) {
        var updated = prefs
        change(&updated)
        updated.quietHours = NotificationSettingsRules.normalized(updated.quietHours)
        guard updated != prefs else { return }
        do {
            try service.save(updated)
            errorMessage = nil
        } catch {
            errorMessage = String(interface: LocalizedStringResource(
                "notificationSettings.error.save", defaultValue: "We could not save this change. Try again."
            ))
        }
    }

    func setQuietHours(on: Bool) {
        let updated = NotificationSettingsRules.togglingQuietHours(prefs, on: on)
        update { $0 = updated }
    }

    func setQuietFrom(_ date: Date) {
        let minutes = NotificationSettingsRules.minutes(of: date, calendar: calendar)
        update {
            $0.quietHours = QuietHoursWindow(fromMinutes: minutes, untilMinutes: $0.quietHours?.untilMinutes ?? 0)
        }
    }

    func setQuietUntil(_ date: Date) {
        let minutes = NotificationSettingsRules.minutes(of: date, calendar: calendar)
        update { $0.quietHours = QuietHoursWindow(fromMinutes: $0.quietHours?.fromMinutes ?? 0, untilMinutes: minutes) }
    }

    func setReminderTime(_ date: Date) {
        let minutes = NotificationSettingsRules.minutes(of: date, calendar: calendar)
        update { $0.reminderTimeMinutes = minutes }
    }
}
