//
//  NotificationPrefsStoring.swift
//  BelloHub
//

/// Where her notification choices live between launches. A protocol so the settings screen is tested in memory.
@MainActor
protocol NotificationPrefsStoring: AnyObject {
    func load() -> NotificationPrefs?
    func save(_ prefs: NotificationPrefs) throws
}
