//
//  OfflineAccountDeleter.swift
//  BelloHub
//

#if DEBUG
/// No server: only this iPhone is cleared and the done screen says so. DEBUG only, for UI-test launches (no network),
/// `-devLogin` runs (whose token the server rightly refuses) and previews; the app uses `RemoteAccountDeleter`.
struct OfflineAccountDeleter: AccountDeleting {
    func deleteAccount(_ request: AccountDeletionRequest) async throws -> AccountDeletionOutcome {
        .deviceOnly
    }
}
#endif
