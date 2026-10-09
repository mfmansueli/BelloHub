//
//  InboxPublicKey.swift
//  BelloHub
//

import CryptoKit
import Foundation

/// The public half of her sealed-mailbox key pair, as the booking page and the server hold it (API.md section 4,
/// `InboxKey`): clients seal their health form to it, only her phone can open it (docs/06-PRIVACY-SECURITY.md
/// section 3). `alg` names the HPKE suite (X25519, HKDF-SHA256, ChaCha20-Poly1305) the web and the app share.
struct InboxPublicKey: Codable, Equatable, Hashable, Sendable {
    static let algorithm = "hpke-v1"

    /// `base64url(SHA-256(pub)[0..<8])`.
    let keyId: String
    let alg: String
    /// `base64url` of the 32 raw bytes of the X25519 public key, no padding.
    let pub: String

    init(publicKey: Curve25519.KeyAgreement.PublicKey) {
        let raw = publicKey.rawRepresentation
        keyId = KeyDerivation.keyID(forPublicKey: raw)
        alg = Self.algorithm
        pub = raw.base64URLEncodedString()
    }

    init(keyId: String, pub: String) {
        self.keyId = keyId
        alg = Self.algorithm
        self.pub = pub
    }
}
