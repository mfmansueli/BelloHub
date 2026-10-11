//
//  PushTokenProviding.swift
//  BelloHub
//

import Foundation

/// Where the app's push token comes from (FCM in the app, nothing in UI tests). The only code that touches the
/// messaging SDK is the implementation in `Managers/Firebase/`; `PushService` sees tokens, never the SDK.
protocol PushTokenProviding: Sendable {
    /// The current registration token and every refresh after it. Finishes when `stop()` is called.
    func tokens() -> AsyncStream<String>
    /// Hands the APNs device token to the provider (FCM maps it to its own token).
    func setAPNSToken(_ deviceToken: Data)
    /// Asks the system for the APNs token (registers for remote notifications).
    @MainActor func registerForRemoteNotifications()
}
