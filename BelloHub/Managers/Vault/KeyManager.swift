//
//  KeyManager.swift
//  BelloHub
//

import CryptoKit
import Foundation
import Observation
import Security

/// Owns the seed and the derived keys of the signed-in professional. The seed is created on first use, kept in
/// iCloud Keychain through `KeyStoring`, and turned into keys held in memory only while the app is unlocked.
/// Showing the recovery words requires Face ID or the passcode **before** calling `recoveryPhrase()`: that check
/// is the caller's (S3 app lock, S10 recovery screen), this type never prompts.
@MainActor
@Observable
final class KeyManager {
    enum Status: Equatable {
        /// Not looked at yet.
        case unknown
        /// This device has no seed: new phone with iCloud Keychain off. Restore with the 12 words.
        case needsRestore
        case locked
        case unlocked
    }

    private(set) var status: Status = .unknown
    private let store: any KeyStoring
    private let holder: VaultKeyHolder

    /// What the repository's codec reads keys from.
    var keyProvider: any VaultKeyProviding { holder }

    init(store: any KeyStoring = KeychainKeyStore(), holder: VaultKeyHolder = VaultKeyHolder()) {
        self.store = store
        self.holder = holder
    }

    // MARK: - Lifecycle

    /// Before the first sensitive write: reads the seed, creating one if the device has never had one **and**
    /// this is a first launch (`createIfMissing`). A device that lost its seed must restore, not silently start a
    /// new vault, or her old records would become unreadable.
    func prepare(createIfMissing: Bool) throws {
        if let seed = try store.loadSeed() {
            holder.install(entropy: seed)
            status = .unlocked
        } else if createIfMissing {
            let seed = try Self.randomEntropy()
            try store.saveSeed(seed)
            holder.install(entropy: seed)
            status = .unlocked
        } else {
            status = .needsRestore
        }
    }

    /// Clears every key from memory (app lock, background grace period over).
    func lock() {
        holder.clear()
        if status == .unlocked { status = .locked }
    }

    func unlock() throws {
        guard let seed = try store.loadSeed() else {
            status = .needsRestore
            throw VaultError.noSeed
        }
        holder.install(entropy: seed)
        status = .unlocked
    }

    // MARK: - Recovery

    /// The 12 words for the stored seed. The caller has already asked for Face ID.
    func recoveryPhrase() throws -> RecoveryPhrase {
        guard let seed = try store.loadSeed() else { throw VaultError.noSeed }
        return try RecoveryPhrase(entropy: seed)
    }

    /// Replaces the seed with the one the words encode, on a phone that cannot get it from iCloud Keychain.
    func restore(from phrase: RecoveryPhrase) throws {
        try store.saveSeed(phrase.entropy)
        holder.install(entropy: phrase.entropy)
        status = .unlocked
    }

    // MARK: - Inbox key pair (sealed mailbox)

    /// The X25519 key pair of a generation, for opening envelopes. Only `MailboxService` should call this.
    func inboxPrivateKey(generation: Int = 1) throws -> Curve25519.KeyAgreement.PrivateKey {
        try KeyDerivation.inboxPrivateKey(rootKey: holder.rootKey(), generation: generation)
    }

    private static func randomEntropy() throws -> Data {
        var bytes = [UInt8](repeating: 0, count: KeyDerivation.entropyLength)
        guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess else {
            throw VaultError.entropyUnavailable
        }
        return Data(bytes)
    }
}
