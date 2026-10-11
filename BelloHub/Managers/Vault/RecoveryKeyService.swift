//
//  RecoveryKeyService.swift
//  BelloHub
//

import Foundation
import Observation

/// The recovery key screen's door to the seed (7.9, docs/06-PRIVACY-SECURITY.md section 4.2): the 12 words are
/// handed out only after Face ID or the passcode succeeded **on this call**, never cached, and the "saved" status is a
/// local non-secret date. Restoring on a new phone (the 12 words typed back) also goes through here.
@MainActor
@Observable
final class RecoveryKeyService {
    private(set) var status: RecoveryKeyStatus

    private let keyManager: KeyManager
    private let biometrics: any BiometricAuthenticating
    private let defaults: UserDefaults
    private let now: @Sendable () -> Date

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
        status = (defaults.object(forKey: DefaultsKey.recoveryKeySavedAt) as? Date).map { .saved(on: $0) } ?? .notSaved
    }

    var biometryKind: BiometryKind { biometrics.kind }

    // MARK: - Reveal

    enum RevealOutcome: Equatable {
        case revealed(RecoveryPhrase)
        case cancelled
        case notRecognized
        /// This iPhone has no seed: nothing to show, she must restore first.
        case noKey
    }

    /// Asks for Face ID or the passcode, then returns the words. `unavailable` (no passcode on the phone) counts as
    /// passed, as the app lock does: there is nothing stronger to ask for.
    func reveal() async -> RevealOutcome {
        let reason = String(interface: LocalizedStringResource(
            "recoveryKey.reason", defaultValue: "Show your recovery key."
        ))
        switch await biometrics.authenticate(reason: reason) {
        case .success, .unavailable:
            do {
                return .revealed(try keyManager.recoveryPhrase())
            } catch {
                return .noKey
            }
        case .cancelled:
            return .cancelled
        case .failed:
            return .notRecognized
        }
    }

    // MARK: - Status

    func markSaved() {
        let date = now()
        defaults.set(date, forKey: DefaultsKey.recoveryKeySavedAt)
        status = .saved(on: date)
    }

    // MARK: - Restore

    /// Installs the seed the words encode. The caller shows the parse error (`RecoveryPhrase.Failure`) by position.
    func restore(words text: String) throws {
        let phrase = try RecoveryPhrase(parsing: text)
        try keyManager.restore(from: phrase)
    }
}
