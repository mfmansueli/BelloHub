//
//  SyncStatusReducer.swift
//  BelloHub
//

/// How one `SyncEvent` changes the `SyncStatus`. Pure and table-tested.
enum SyncStatusReducer {
    static func reduce(_ current: SyncStatus, with event: SyncEvent) -> SyncStatus {
        if let failure = event.failure {
            return status(for: failure)
        }
        return event.isFinished ? .synced(event.date) : .syncing
    }

    static func status(for failure: SyncFailure) -> SyncStatus {
        switch failure {
        case .notSignedIn: .iCloudUnavailable
        case .quotaExceeded: .iCloudFull
        case .networkUnavailable: .offline
        case .other: .error
        }
    }
}
