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
    /// When she said she put her 12 words somewhere safe (a `Date`); absent until she does.
    static let recoveryKeySavedAt = "recoveryKey.savedAt"
    /// Her notification choices (`NotificationPrefs` as JSON).
    static let notificationPrefs = "notifications.prefs"
    /// Notifications say "A client" instead of a name on the lock screen. Default on.
    static let hideNamesOnLockScreen = "notifications.hideNames"
    /// Apple Calendar write-through switched on.
    static let appleCalendarEnabled = "integrations.appleCalendar"

    /// Everything that belongs to the account and goes with it when the account is deleted. Device-wide settings
    /// (the lock) stay.
    static let clearedOnAccountDeletion = [
        setupCompletedUserID, localDevUser, recoveryKeySavedAt, notificationPrefs, hideNamesOnLockScreen,
        appleCalendarEnabled
    ]
}
