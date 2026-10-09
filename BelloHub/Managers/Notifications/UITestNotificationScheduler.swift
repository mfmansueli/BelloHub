//
//  UITestNotificationScheduler.swift
//  BelloHub
//

#if DEBUG
import Foundation

/// What a UI-test launch uses in place of the notification center: it schedules nothing, so a test never leaves
/// notifications on the simulator or waits for a permission dialog. DEBUG only.
struct UITestNotificationScheduler: NotificationScheduling {
    func replaceScheduled(with notifications: [PlannedNotification]) async {}
    func removeAllScheduled() async {}
}
#endif
