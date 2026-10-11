//
//  NotificationSettingsRules.swift
//  BelloHub
//

import Foundation

/// The rules of Notification settings (7.4): the quiet-hours defaults, the minutes-of-day conversions the time
/// pickers need, and the permission states the screen must explain honestly.
enum NotificationSettingsRules {
    /// 22:00 to 07:00, the prototype's night.
    static let defaultQuietHours = QuietHoursWindow(fromMinutes: 22 * 60, untilMinutes: 7 * 60)

    /// A quiet window that starts and ends at the same minute silences nothing: treat it as off.
    static func normalized(_ window: QuietHoursWindow?) -> QuietHoursWindow? {
        guard let window, window.fromMinutes != window.untilMinutes else { return nil }
        return window
    }

    static func togglingQuietHours(_ prefs: NotificationPrefs, on: Bool) -> NotificationPrefs {
        var updated = prefs
        updated.quietHours = on ? (prefs.quietHours ?? defaultQuietHours) : nil
        return updated
    }

    /// A `Date` on a reference day for the picker, from minutes since midnight.
    static func date(forMinutes minutes: Int, calendar: Calendar) -> Date {
        let midnight = calendar.startOfDay(for: Date(timeIntervalSinceReferenceDate: 0))
        return calendar.date(byAdding: .minute, value: minutes, to: midnight) ?? midnight
    }

    static func minutes(of date: Date, calendar: Calendar) -> Int {
        calendar.component(.hour, from: date) * 60 + calendar.component(.minute, from: date)
    }

    /// What the top of the screen says about the system permission.
    enum PermissionNotice: Equatable, Sendable {
        /// Never asked: offer the system dialog.
        case ask
        /// Refused in Settings: the switches below do nothing until she changes that there.
        case denied
        case granted
    }

    static func notice(for status: PermissionStatus) -> PermissionNotice {
        switch status {
        case .notDetermined: .ask
        case .denied: .denied
        case .granted: .granted
        }
    }
}
