//
//  NotificationPrefs.swift
//  BelloHub
//

import Foundation

/// What reaches the professional, and what is prepared for her clients. Urgent alerts (a client running late,
/// a same-day cancellation) ignore quiet hours.
struct NotificationPrefs: Hashable, Codable, Sendable {
    var newBookings: Bool
    var cancellations: Bool
    var clientCheckIns: Bool
    var followUpsDue: Bool
    var birthdays: Bool
    var quietHours: QuietHoursWindow?
    var dailySummary: Bool
    var clientRemindersEnabled: Bool
    /// When the "reminders ready" notification posts the evening before, in minutes from local midnight.
    var reminderTimeMinutes: Int

    static let standard = NotificationPrefs(
        newBookings: true, cancellations: true, clientCheckIns: true, followUpsDue: true, birthdays: true,
        quietHours: nil, dailySummary: false, clientRemindersEnabled: true, reminderTimeMinutes: 18 * 60
    )
}
