//
//  UITestBiometrics.swift
//  BelloHub
//

#if DEBUG
import os

/// A Face ID that answers the way a UI test tells it to (`-uiBiometrics success|fail|cancelFirst`), because a test
/// cannot show its face. DEBUG only: a Release build must never skip the real check.
final class UITestBiometrics: BiometricAuthenticating, Sendable {
    enum Mode: String, Sendable {
        case success
        case fail
        /// The first prompt is dismissed and every later one succeeds: how a test sees the Locked screen and then
        /// unlocks it with a tap.
        case cancelFirst
        /// The first prompt succeeds and every later one is dismissed: how a test opens the app and then sees it lock
        /// again and stay locked.
        case successOnce
    }

    let kind = BiometryKind.faceID
    private let mode: Mode
    private let attempts = OSAllocatedUnfairLock(initialState: 0)

    init(mode: Mode) {
        self.mode = mode
    }

    func authenticate(reason: String) async -> BiometricResult {
        let attempt = attempts.withLock { count -> Int in
            count += 1
            return count
        }
        switch mode {
        case .success: return .success
        case .fail: return .failed
        case .cancelFirst: return attempt == 1 ? .cancelled : .success
        case .successOnce: return attempt == 1 ? .success : .cancelled
        }
    }
}
#endif
