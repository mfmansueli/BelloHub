//
//  FakeInboxKeys.swift
//  BelloHubTests
//

@testable import BelloHub
import CryptoKit
import Foundation

/// Her inbox key pair in a test: one generation, made fresh, that can be "locked" like the app before Face ID.
/// `seal` makes an envelope the way the booking page does, addressed to this key.
@MainActor
final class FakeInboxKeys: InboxKeyOpening {
    let privateKey = Curve25519.KeyAgreement.PrivateKey()
    var isLocked = false
    private(set) var lookups: [String] = []

    var keyID: String { KeyDerivation.keyID(forPublicKey: privateKey.publicKey.rawRepresentation) }

    func inboxPrivateKey(forKeyID keyId: String) throws -> Curve25519.KeyAgreement.PrivateKey? {
        lookups.append(keyId)
        if isLocked { throw VaultError.locked }
        return keyId == keyID ? privateKey : nil
    }

    /// `json` sealed to this key for `kind` and `itemId`.
    func seal(_ json: [String: Any], kind: MailboxKind, itemId: String) throws -> SealedEnvelope {
        let plaintext = try JSONSerialization.data(withJSONObject: json)
        return try EnvelopeOpener.seal(plaintext, to: privateKey.publicKey, kind: kind, itemId: itemId)
    }
}
