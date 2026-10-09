//
//  AppLockService.swift
//  BelloHub
//

import Foundation
import Observation

/// The app lock: it clears the vault keys from memory and asks for Face ID or the passcode before the app opens
/// again. The records stay encrypted on disk either way; the lock is what keeps a borrowed or stolen phone from
/// reading them (docs/06-PRIVACY-SECURITY.md section 5).
@MainActor
@Observable
final class AppLockService {
    private(set) var isLocked = false
    private(set) var isAuthenticating = false
    private(set) var failure: UnlockFailure?

    private let keyManager: KeyManager
    private let biometrics: any BiometricAuthenticating
    private let defaults: UserDefaults
    private let now: @Sendable () -> Date
    private var leftAt: Date?

    init(
        keyManager: KeyManager,
        biometrics: any BiometricAuthenticating = LocalAuthenticationBiometrics(),
        defaults: UserDefaults = .standard,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.keyManager = keyManager
        self.biometrics = biometrics
        self.defaults = defaults
        self.now = now
    }

    // MARK: - Settings

    /// On unless she turned it off (Privacy and security, S10).
    var isEnabled: Bool {
        defaults.object(forKey: DefaultsKey.lockEnabled) as? Bool ?? true
    }

    var graceSeconds: Int {
        LockPolicy.normalizedGrace(defaults.object(forKey: DefaultsKey.lockGraceSeconds) as? Int)
    }

    var biometryKind: BiometryKind { biometrics.kind }

    // MARK: - Lifecycle

    /// A cold launch of a workspace that is already set up: locked, whatever the grace period says. With the lock
    /// off the vault opens straight away.
    func prepareForLaunch() {
        failure = nil
        if isEnabled {
            keyManager.lock()
            isLocked = true
        } else {
            do {
                try keyManager.unlock()
                isLocked = false
            } catch {
                failure = .keyMissing
                isLocked = true
            }
        }
    }

    /// She just proved who she is with an SMS code, so the vault opens without asking for her face as well.
    func openAfterSignIn() {
        failure = nil
        open()
    }

    /// The app left the foreground.
    func sceneDidLeave() {
        guard !isLocked else { return }
        leftAt = now()
    }

    /// The app is back in the foreground: lock if she was away longer than the grace period.
    ///
    /// Only a real trip to the background counts. The system Face ID sheet, Control Center and notification pulls
    /// also turn the scene inactive and active again without a background, and on a real iPhone that happens right
    /// after a successful unlock: treating "no background seen" as "lock" put her in a loop that never reached the
    /// app. The cold launch is locked by `prepareForLaunch`, not here. The time away is used once.
    func sceneDidReturn() {
        guard !isLocked, let leftAt else { return }
        self.leftAt = nil
        if LockPolicy.shouldLock(isEnabled: isEnabled, leftAt: leftAt, now: now(), graceSeconds: graceSeconds) {
            lockNow()
        }
    }

    func lockNow() {
        keyManager.lock()
        failure = nil
        isLocked = true
    }

    /// Asks for Face ID or the passcode and opens the vault. Safe to call from a button and from `.task`: a second
    /// call while the first is on screen does nothing.
    func unlock() async {
        guard isLocked, !isAuthenticating else { return }
        isAuthenticating = true
        defer { isAuthenticating = false }
        let reason = String(localized: "locked.reason", defaultValue: "Open your clients and records.")
        let result = await biometrics.authenticate(reason: reason)
        switch result {
        case .success, .unavailable:
            open()
        case .cancelled:
            break
        case .failed:
            failure = .notRecognized
        }
    }

    private func open() {
        do {
            try keyManager.unlock()
            failure = nil
            leftAt = nil
            isLocked = false
        } catch {
            failure = .keyMissing
        }
    }
}
