//
//  AccountDeleting.swift
//  BelloHub
//

/// The server half of deleting her account: the `deleteAccount` function removes the account document, bookings and
/// mailbox, and revokes the Apple token with the fresh authorization code in the request (D44). The app calls it
/// through `RemoteAccountDeleter`; DEBUG launches without a server use `OfflineAccountDeleter` (`deviceOnly`). The
/// device half (vault, key, session) is `AccountService`'s and runs only after this answered without throwing.
protocol AccountDeleting: Sendable {
    func deleteAccount(_ request: AccountDeletionRequest) async throws -> AccountDeletionOutcome
}
