//
//  DefaultsKey.swift
//  BelloHub
//

/// Every `UserDefaults` key of the app, in one place (CLAUDE.md section 2). Secrets, key material and tokens never go
/// here: they live in the Keychain. Names are namespaced by feature (`lock.enabled`) so a key is never reused by
/// accident, and none of them is ever renamed once shipped (an old value would be silently ignored).
enum DefaultsKey {
    /// The user id whose workspace setup finished on this phone. A different user signing in runs the setup again.
    static let setupCompletedUserID = "setup.completedUserID"
    /// Whether the app asks for Face ID or the passcode after it was in the background. Default on.
    static let lockEnabled = "lock.enabled"
    /// Seconds in the background before the lock returns (`LockPolicy.graceOptions`). Default 60.
    static let lockGraceSeconds = "lock.graceSeconds"
    /// The signed-in dummy user of `LocalDevAuthProvider`. Exists only in DEBUG builds.
    static let localDevUser = "session.localDevUser"
    /// The on-device assistant's preferences (`AIPreferences`, JSON). Absent means the defaults.
    static let aiPreferences = "ai.preferences"
    /// The user id whose booking page she put online from this phone (`PublishingService`). While it equals the
    /// signed-in
    /// user, changes to her page are published by themselves; stopping removes it.
    static let publishingOnlineUserID = "publishing.onlineUserID"
    /// `NotificationPrefs` as JSON: what reaches her and when (`DefaultsNotificationPrefsStore`).
    static let notificationPrefs = "notifications.prefs"
}
