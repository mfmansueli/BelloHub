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
    /// When she said she put her 12 words somewhere safe (a `Date`); absent until she does.
    static let recoveryKeySavedAt = "recoveryKey.savedAt"
    /// Her notification choices (`NotificationPrefs` as JSON).
    static let notificationPrefs = "notifications.prefs"
    /// Notifications say "A client" instead of a name on the lock screen. Default on.
    static let hideNamesOnLockScreen = "notifications.hideNames"
    /// Apple Calendar write-through switched on.
    static let appleCalendarEnabled = "integrations.appleCalendar"
    /// The language of the interface she chose in Language and region (`InterfaceLanguage.storageValue`): `"system"`
    /// or a localization id. A device setting, read before the vault opens (lock screen, welcome), so it stays when the
    /// account goes.
    static let interfaceLanguage = "interface.language"
    /// The `AppleLanguages` value the app itself last wrote, so a change made later in iOS Settings is recognized
    /// (`InterfaceLanguage.reconciled`).
    static let interfaceAppleLanguagesWritten = "interface.appleLanguagesWritten"

    /// Everything that belongs to the account and goes with it when the account is deleted. Device-wide settings
    /// (the lock) stay.
    static let clearedOnAccountDeletion = [
        setupCompletedUserID, localDevUser, recoveryKeySavedAt, notificationPrefs, hideNamesOnLockScreen,
        appleCalendarEnabled, aiPreferences, publishingOnlineUserID, accountDeletionConfirmed
    ]
    /// The server already deleted this account (`"<userID>|<outcome>"`, `AccountService`): a retry after a wipe that
    /// failed or an app killed mid-way goes straight to the wipe instead of asking a server that no longer knows her.
    static let accountDeletionConfirmed = "account.deletionConfirmed"
    /// Prefix of the per-user queue of writes waiting for the server (`OutboundQueue`, JSON): `<prefix>.<userID>`.
    static let outboundQueue = "inbox.outbound"
    /// Prefix of the per-user `InboxSnapshot` (`BookingSyncService`, JSON): `<prefix>.<userID>`.
    static let inboxSnapshot = "inbox.snapshot"
    /// Prefix of the per-user list of sealed items the phone could not open (`MailboxService`, JSON, ids and times
    /// only): `<prefix>.<userID>`.
    static let mailboxUndecryptable = "mailbox.undecryptable"
    /// Prefix of the per-user FCM token the server knows (`PushService`): `<prefix>.<userID>`.
    static let pushRegisteredToken = "push.registeredToken"
}
