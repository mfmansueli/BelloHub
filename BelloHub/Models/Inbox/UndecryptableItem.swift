//
//  UndecryptableItem.swift
//  BelloHub
//

import Foundation

/// A sealed item the phone could not open or read (docs/06-PRIVACY-SECURITY.md section 3.5, step 5): the id, the
/// time and why, nothing else. The item stays on the server until its TTL; the inbox asks her to have the client send
/// it again.
struct UndecryptableItem: Identifiable, Hashable, Codable, Sendable {
    enum Reason: String, PersistedEnum {
        /// The version or suite is not the one the app opens.
        case unsupported
        /// No key of hers matches `keyId`.
        case unknownKey
        /// The ciphertext did not authenticate (tampered, misaddressed, wrong key).
        case openFailed
        /// It opened, but the plaintext is not a payload the app knows.
        case badPayload
        /// It opened, but no booking or client matches it yet; retried on the next sync.
        case unmatched

        static let fallback = Reason.openFailed
    }

    let id: String
    let kind: MailboxKind
    let reason: Reason
    let at: Date
}
