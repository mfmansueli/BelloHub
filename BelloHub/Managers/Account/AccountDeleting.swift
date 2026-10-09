//
//  AccountDeleting.swift
//  BelloHub
//

/// The server half of deleting her account: the `deleteAccount` function removes the account document, bookings and
/// mailbox, and revokes the Apple token with the fresh authorization code in the request (D44). S8 wires the real
/// call; until then `OfflineAccountDeleter` answers `deviceOnly`. The device half (vault, key, session) is
/// `AccountService`'s and never depends on this answer.
protocol AccountDeleting: Sendable {
    func deleteAccount(_ request: AccountDeletionRequest) async throws -> AccountDeletionOutcome
}
