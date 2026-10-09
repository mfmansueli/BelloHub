//
//  NoPushTokenProvider.swift
//  BelloHub
//

import Foundation

/// No push: UI tests (no APNs on a simulator, no network) and previews. The stream finishes at once.
struct NoPushTokenProvider: PushTokenProviding {
    func tokens() -> AsyncStream<String> { AsyncStream { $0.finish() } }
    func setAPNSToken(_ deviceToken: Data) {}
    func registerForRemoteNotifications() {}
}
