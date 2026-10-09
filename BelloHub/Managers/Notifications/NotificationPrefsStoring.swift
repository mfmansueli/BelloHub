//
//  NotificationPrefsStoring.swift
//  BelloHub
//

import Foundation

/// Where her notification choices live. The settings screen (S10) writes them; the scheduler only reads. Behind a
/// protocol so the scheduling is tested with fixed prefs.
protocol NotificationPrefsStoring: Sendable {
    func load() -> NotificationPrefs
    func save(_ prefs: NotificationPrefs)
}
