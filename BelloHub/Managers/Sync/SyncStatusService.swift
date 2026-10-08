//
//  SyncStatusService.swift
//  BelloHub
//

import Foundation
import Observation

/// The state of the vault's iCloud sync, shared through the environment. One observation for the whole app
/// (`startListening()` / `stopListening()`, which resets the state, as CLAUDE.md section 2 asks).
@MainActor
@Observable
final class SyncStatusService {
    private(set) var status: SyncStatus
    private let source: any SyncEventSource
    private let initial: SyncStatus
    private var listening: Task<Void, Never>?

    /// - Parameter initial: `.localOnly` until CloudKit is switched on, `.syncing` once it is.
    init(source: any SyncEventSource, initial: SyncStatus = .localOnly) {
        self.source = source
        self.initial = initial
        self.status = initial
    }

    func startListening() {
        guard listening == nil else { return }
        let events = source.events()
        listening = Task { [weak self] in
            for await event in events {
                guard let self else { return }
                self.status = SyncStatusReducer.reduce(self.status, with: event)
            }
        }
    }

    func stopListening() {
        listening?.cancel()
        listening = nil
        status = initial
    }

    /// The network monitor reports a lost or regained connection (S8). Regaining it waits for the next sync event.
    func setOffline(_ isOffline: Bool) {
        if isOffline {
            status = .offline
        } else if status == .offline {
            status = .syncing
        }
    }
}
