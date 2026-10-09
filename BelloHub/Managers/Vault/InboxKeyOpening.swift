//
//  InboxKeyOpening.swift
//  BelloHub
//

import CryptoKit

/// The private half of her sealed-mailbox keys, for opening envelopes (docs/06-PRIVACY-SECURITY.md section 3.2):
/// the current generation and the earlier ones, so an item sealed before a rotation still opens. Only `MailboxService`
/// asks for it (docs/04-ARCHITECTURE.md, boundary 3), and the key never leaves the process.
@MainActor
protocol InboxKeyOpening: AnyObject {
    /// The private key whose public half has `keyId`, or nil when no generation of hers matches. Throws
    /// `VaultError.locked` or `.noSeed` while the keys are not in memory.
    func inboxPrivateKey(forKeyID keyId: String) throws -> Curve25519.KeyAgreement.PrivateKey?
}
