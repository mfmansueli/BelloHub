//
//  KeyDerivation.swift
//  BelloHub
//

import CryptoKit
import Foundation

/// The key hierarchy of docs/06-PRIVACY-SECURITY.md section 4.1 (the doc calls the root key `masterKey`; the code
/// says `rootKey`), pure so known-answer tests pin it:
///
///     entropy E (128 bits)
///      └─ rootKey = HKDF-SHA256(ikm: E, salt: "bellohub.v1", info: "master")
///          ├─ vaultKey    = HKDF(ikm: rootKey, salt: none, info: "bellohub/vault/aes256gcm/v1")
///          └─ inboxSeed_g = HKDF(ikm: rootKey, salt: none, info: "bellohub/inbox/x25519/v1/g<g>")
///              └─ X25519 private key → public key → keyId
///
/// Everything is recomputable from E, which is what the 12 recovery words encode. **Never change a label
/// or a parameter**: every existing record was encrypted with these keys. A change needs a new version
/// and a migration.
enum KeyDerivation {
    static let entropyLength = 16

    static func rootKey(entropy: Data) -> SymmetricKey {
        HKDF<SHA256>.deriveKey(
            inputKeyMaterial: SymmetricKey(data: entropy),
            salt: Data("bellohub.v1".utf8),
            info: Data("master".utf8),
            outputByteCount: 32
        )
    }

    static func vaultKey(rootKey: SymmetricKey) -> SymmetricKey {
        HKDF<SHA256>.deriveKey(
            inputKeyMaterial: rootKey,
            salt: Data(),
            info: Data("bellohub/vault/aes256gcm/v1".utf8),
            outputByteCount: 32
        )
    }

    /// The 32 bytes behind the inbox key pair of `generation` (1, 2, ...). A rotation moves to the next
    /// generation; older ones stay derivable to open envelopes still in the mailbox.
    static func inboxSeed(rootKey: SymmetricKey, generation: Int) -> Data {
        let key = HKDF<SHA256>.deriveKey(
            inputKeyMaterial: rootKey,
            salt: Data(),
            info: Data("bellohub/inbox/x25519/v1/g\(generation)".utf8),
            outputByteCount: 32
        )
        return key.withUnsafeBytes { Data($0) }
    }

    static func inboxPrivateKey(rootKey: SymmetricKey, generation: Int) throws
        -> Curve25519.KeyAgreement.PrivateKey {
        try Curve25519.KeyAgreement.PrivateKey(
            rawRepresentation: inboxSeed(rootKey: rootKey, generation: generation)
        )
    }

    /// `base64url(SHA-256(publicKey)[0..<8])`, no padding. Short enough for a page footer, long enough to be
    /// unique per professional.
    static func keyID(forPublicKey publicKey: Data) -> String {
        Data(SHA256.hash(data: publicKey).prefix(8)).base64URLEncodedString()
    }
}

extension Data {
    /// RFC 4648 section 5, without padding: the form used in keys, ids and envelopes.
    func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
