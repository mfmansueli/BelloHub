//
//  VaultWipingRepository.swift
//  BelloHub
//

/// The one destructive door of the vault: deleting the account (7.1) empties it on this iPhone, and with CloudKit
/// mirroring on, in her private database too. Nothing else calls it, and the caller has shown the explicit
/// confirmation first (docs/03-BUILD-PLAN.md S10 exit: the vault is cleared only after an explicit confirmation).
protocol VaultWipingRepository: Sendable {
    /// Deletes every item of every kind, the registration ledger included (the account is gone, D42 no longer applies).
    func wipeEverything() async throws
}
