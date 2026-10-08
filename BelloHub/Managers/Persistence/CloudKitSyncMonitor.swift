//
//  CloudKitSyncMonitor.swift
//  BelloHub
//

import CloudKit
import CoreData

/// Turns the CloudKit mirroring notifications (`NSPersistentCloudKitContainer.eventChangedNotification`, which
/// SwiftData posts too) into `SyncEvent`s. The only file that knows the CloudKit error codes.
struct CloudKitSyncMonitor: SyncEventSource {
    func events() -> AsyncStream<SyncEvent> {
        AsyncStream { continuation in
            let task = Task {
                let name = NSPersistentCloudKitContainer.eventChangedNotification
                for await notification in NotificationCenter.default.notifications(named: name) {
                    let event = notification.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey]
                        as? NSPersistentCloudKitContainer.Event
                    guard let event else { continue }
                    continuation.yield(Self.map(finishedAt: event.endDate, error: event.error))
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    static func map(finishedAt endDate: Date?, error: (any Error)?) -> SyncEvent {
        SyncEvent(isFinished: endDate != nil, failure: error.map(failure(for:)), date: endDate ?? Date())
    }

    static func failure(for error: any Error) -> SyncFailure {
        guard let cloudError = error as? CKError else { return .other }
        switch cloudError.code {
        case .notAuthenticated, .accountTemporarilyUnavailable, .managedAccountRestricted:
            return .notSignedIn
        case .quotaExceeded:
            return .quotaExceeded
        case .networkUnavailable, .networkFailure:
            return .networkUnavailable
        default:
            return .other
        }
    }
}
