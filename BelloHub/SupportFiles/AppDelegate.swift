//
//  AppDelegate.swift
//  BelloHub
//

import UIKit
import UserNotifications

/// The UIKit door for push (CLAUDE.md section 2, "Push/deep links: AppDelegate posts a `Notification.Name`, the UI
/// listens"): the APNs token goes to the push provider, a remote notification becomes a `PushEvent`, and a tapped
/// notification becomes one with `wasOpened`. It reads no SDK of its own: `PushBridge` is set by `AppDependencies`.
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        PushBridge.shared.provider?.setAPNSToken(deviceToken)
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: any Error) {
        // No APNs (simulator, missing entitlement): the app works without push; the inbox syncs when opened.
    }

    /// A silent push (`content-available`) or a visible one delivered while the app runs. The services sync on the
    /// event; the system gives the app a moment in the background for it.
    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any]
    ) async -> UIBackgroundFetchResult {
        guard let event = PushEvent(userInfo: userInfo, wasOpened: false) else { return .noData }
        await MainActor.run { event.post() }
        // Give the sync a moment before the system suspends the app; the services finish by themselves when it is
        // longer than this.
        try? await Task.sleep(for: .seconds(8))
        return .newData
    }

    // MARK: - UNUserNotificationCenterDelegate

    /// A visible push while the app is open: show it (iOS already resolved the generic text from the catalog) and
    /// sync. A key the app has no string for is not shown raw (`PushPresentation`).
    func userNotificationCenter(
        _ center: UNUserNotificationCenter, willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        let content = notification.request.content
        if let event = PushEvent(userInfo: content.userInfo, wasOpened: false) {
            await MainActor.run { event.post() }
        }
        return PushPresentation.options(forBody: content.body)
    }

    /// She tapped a notification: the UI opens the inbox.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse
    ) async {
        let userInfo = response.notification.request.content.userInfo
        let event = PushEvent(userInfo: userInfo, wasOpened: true) ?? PushEvent(kind: .mailbox, wasOpened: true)
        await MainActor.run { event.post() }
    }
}
