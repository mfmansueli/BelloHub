//
//  SyncEvent.swift
//  BelloHub
//

import Foundation

/// One step reported by the sync engine, reduced to what the status needs. The CloudKit types never leave
/// `Managers/Persistence/`.
struct SyncEvent: Equatable, Sendable {
    /// False while the step is running.
    let isFinished: Bool
    let failure: SyncFailure?
    let date: Date
}
