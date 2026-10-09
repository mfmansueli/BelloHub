//
//  OfflineAccountDeleter.swift
//  BelloHub
//

/// No server yet: only this iPhone is cleared and the screen says so. Replaced by the Firebase function in S8.
struct OfflineAccountDeleter: AccountDeleting {
    func deleteAccount(_ request: AccountDeletionRequest) async throws -> AccountDeletionOutcome {
        .deviceOnly
    }
}
