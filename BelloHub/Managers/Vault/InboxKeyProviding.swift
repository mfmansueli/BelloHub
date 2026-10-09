//
//  InboxKeyProviding.swift
//  BelloHub
//

/// The public half of her sealed-mailbox key, for publishing. The private half never leaves `KeyManager`: it is derived
/// from the recovery seed (docs/06-PRIVACY-SECURITY.md section 4.1), so it is already part of her recovery material and
/// needs no storage of its own. Reading the mailbox (the private half) is the next slice.
@MainActor
protocol InboxKeyProviding: AnyObject {
    /// The key clients seal to, for the current generation. Throws `VaultError.locked` or `.noSeed` while the keys
    /// are not
    /// in memory.
    func currentInboxPublicKey() throws -> InboxPublicKey
}
