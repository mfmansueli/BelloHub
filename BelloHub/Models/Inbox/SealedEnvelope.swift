//
//  SealedEnvelope.swift
//  BelloHub
//

import Foundation

/// What the server stores for one sealed item (docs/06-PRIVACY-SECURITY.md section 3.3): opaque to everyone but her
/// phone. `aad` is rebuilt from the envelope's own fields, so an envelope whose kind, item id or key id was changed does
/// not open.
struct SealedEnvelope: Hashable, Codable, Sendable {
    static let version = 1
    static let suite = "hpke-x25519-hkdf-sha256-chacha20poly1305"

    let v: Int
    let suite: String
    let keyId: String
    let kind: String
    let itemId: String
    /// base64url, 32 bytes.
    let enc: String
    /// base64url, ciphertext plus the 16-byte tag.
    let ct: String

    init(v: Int = SealedEnvelope.version, suite: String = SealedEnvelope.suite, keyId: String, kind: String,
         itemId: String, enc: String, ct: String) {
        self.v = v
        self.suite = suite
        self.keyId = keyId
        self.kind = kind
        self.itemId = itemId
        self.enc = enc
        self.ct = ct
    }

    /// `bellohub/v1|<kind>|<itemId>|<keyId>`.
    var aad: Data { Data("bellohub/v1|\(kind)|\(itemId)|\(keyId)".utf8) }

    /// The app opens only the version and suite it was built for; anything else is rejected before any key is used.
    var isSupported: Bool { v == Self.version && suite == Self.suite }

    var mailboxKind: MailboxKind? { MailboxKind(rawValue: kind) }
}
