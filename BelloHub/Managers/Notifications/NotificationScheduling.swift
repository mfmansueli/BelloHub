//
//  NotificationScheduling.swift
//  BelloHub
//

import Foundation

/// The system's local-notification center behind a protocol, so the planning and the rescheduling are tested without
/// scheduling anything on the phone.
protocol NotificationScheduling: Sendable {
    /// Replaces every notification this app scheduled earlier with `notifications`. One call leaves the phone with
    /// exactly this list, so a visit that moved or was cancelled never keeps an old reminder.
    func replaceScheduled(with notifications: [PlannedNotification]) async

    /// Removes everything this app scheduled (sign-out, or the permission was withdrawn).
    func removeAllScheduled() async
}
