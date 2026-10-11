//
//  FirebaseMessagingManager.swift
//  BelloHub
//

import FirebaseMessaging
import Foundation
import UIKit

/// FCM behind `PushTokenProviding`: the only file that imports the messaging SDK. It hands the APNs token to FCM and
/// publishes the registration token and its refreshes as a stream. Method swizzling is off
/// (`FirebaseAppDelegateProxyEnabled` in the Info.plist), so `AppDelegate` passes the APNs token and the pushes here
/// explicitly. Real pushes need the owner's APNs key in the Firebase console (H4); until then the token stream stays
/// silent on a device and the app behaves as if no push ever came.
///
/// `@unchecked Sendable`: the only mutable state is `TokenContinuations`, which locks; the SDK singleton is
/// thread-safe.
final class FirebaseMessagingManager: NSObject, PushTokenProviding, @unchecked Sendable {
    private let continuations = TokenContinuations()

    override init() {
        super.init()
        Messaging.messaging().delegate = self
    }

    func tokens() -> AsyncStream<String> {
        AsyncStream { continuation in
            let id = continuations.add(continuation)
            continuation.onTermination = { [continuations] _ in continuations.remove(id) }
        }
    }

    func setAPNSToken(_ deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
    }

    @MainActor
    func registerForRemoteNotifications() {
        UIApplication.shared.registerForRemoteNotifications()
    }
}

extension FirebaseMessagingManager: MessagingDelegate {
    nonisolated func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let fcmToken else { return }
        continuations.yield(fcmToken)
    }
}
