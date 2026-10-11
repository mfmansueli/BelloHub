//
//  UserNotificationPoster.swift
//  BelloHub
//

import Foundation
import UserNotifications

/// The real one: `UNUserNotificationCenter` with a nil trigger (delivered at once). Silently does nothing when she
/// has not allowed notifications.
struct UserNotificationPoster: ImmediateNotifying {
    func post(id: String, threadID: String, title: String, body: String) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.threadIdentifier = threadID
        let request = UNNotificationRequest(identifier: id, content: content, trigger: nil)
        try? await UNUserNotificationCenter.current().add(request)
    }
}
