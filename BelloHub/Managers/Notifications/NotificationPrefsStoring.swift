//
//  NotificationPrefsStoring.swift
//  BelloHub
//

import Foundation

/// Where her notification choices live. The settings screen (7.4) writes them; the scheduler (S6) only reads. Behind
/// a protocol so the settings screen is tested in memory and the scheduling with fixed prefs. A missing value reads
/// as `NotificationPrefs.standard`; a save may fail, and the settings screen tells her when it does.
protocol NotificationPrefsStoring: Sendable {
    func load() -> NotificationPrefs
    func save(_ prefs: NotificationPrefs) throws
}
