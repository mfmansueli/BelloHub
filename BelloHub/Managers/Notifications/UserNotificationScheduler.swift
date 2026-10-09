//
//  UserNotificationScheduler.swift
//  BelloHub
//

import Foundation
import UserNotifications

/// The real scheduler: `UNUserNotificationCenter`. Triggers are absolute time intervals from the moment of scheduling,
/// so a daylight-saving change between planning and firing cannot move them; the plan is rebuilt whenever the calendar
/// changes or the app opens.
struct UserNotificationScheduler: NotificationScheduling {
    func replaceScheduled(with notifications: [PlannedNotification]) async {
        let center = UNUserNotificationCenter.current()
        await removeOwnPending(from: center)
        let now = Date()
        for notification in notifications {
            let interval = notification.fireDate.timeIntervalSince(now)
            guard interval > 1 else { continue }
            let content = UNMutableNotificationContent()
            content.title = notification.title
            content.body = notification.body
            content.sound = .default
            content.threadIdentifier = notification.kind.threadID
            let request = UNNotificationRequest(
                identifier: notification.id, content: content,
                trigger: UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
            )
            try? await center.add(request)
        }
    }

    func removeAllScheduled() async {
        await removeOwnPending(from: UNUserNotificationCenter.current())
    }

    private func removeOwnPending(from center: UNUserNotificationCenter) async {
        let pending = await center.pendingNotificationRequests()
        let own = pending.map(\.identifier).filter { $0.hasPrefix(PlannedNotification.identifierPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: own)
    }
}
