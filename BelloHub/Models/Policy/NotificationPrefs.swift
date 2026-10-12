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
    /// An evening nudge when visits are still waiting for their record (completed with nothing written, or drafts).
    /// It only carries a count, like every local notification.
    var recordsToWrite = true

    static let standard = NotificationPrefs(
        newBookings: true, cancellations: true, clientCheckIns: true, followUpsDue: true, birthdays: true,
        quietHours: nil, dailySummary: false, clientRemindersEnabled: true, reminderTimeMinutes: 18 * 60
    )
}

extension NotificationPrefs {
    private enum CodingKeys: String, CodingKey {
        case newBookings, cancellations, clientCheckIns, followUpsDue, birthdays, quietHours, dailySummary
        case clientRemindersEnabled, reminderTimeMinutes, recordsToWrite
    }

    /// Prefs saved before a switch existed read it as its default, so an update never resets her other choices.
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        newBookings = try container.decode(Bool.self, forKey: .newBookings)
        cancellations = try container.decode(Bool.self, forKey: .cancellations)
        clientCheckIns = try container.decode(Bool.self, forKey: .clientCheckIns)
        followUpsDue = try container.decode(Bool.self, forKey: .followUpsDue)
        birthdays = try container.decode(Bool.self, forKey: .birthdays)
        quietHours = try container.decodeIfPresent(QuietHoursWindow.self, forKey: .quietHours)
        dailySummary = try container.decode(Bool.self, forKey: .dailySummary)
        clientRemindersEnabled = try container.decode(Bool.self, forKey: .clientRemindersEnabled)
        reminderTimeMinutes = try container.decode(Int.self, forKey: .reminderTimeMinutes)
        recordsToWrite = try container.decodeIfPresent(Bool.self, forKey: .recordsToWrite) ?? true
    }
}
