//
//  PushPresentation.swift
//  BelloHub
//

import UserNotifications

/// How a push that arrives while the app is open is shown. iOS resolves the server's `loc-key` from the app's string
/// catalog before the delegate sees it; a key the app has no string for (a server newer than the app) comes through
/// as the key itself. On the lock screen nothing can be done about that, but in the foreground the app hides it
/// rather than show "push.booking.new": the event still syncs, and the in-app alerts say what happened.
enum PushPresentation {
    /// True when `body` is a push localization key iOS could not resolve.
    static func isUnresolvedKey(_ body: String) -> Bool {
        body.hasPrefix("push.") && !body.contains(where: \.isWhitespace)
    }

    /// Banner, list and sound for a readable alert; nothing for a raw key.
    static func options(forBody body: String) -> UNNotificationPresentationOptions {
        isUnresolvedKey(body) ? [] : [.banner, .list, .sound]
    }
}
