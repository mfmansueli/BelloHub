//
//  TaskBag.swift
//  BelloHub
//

import Foundation
import os

/// The tasks that watch the vault for a ViewModel. A main-actor class cannot touch its own state in `deinit`, so the
/// tasks live in this nonisolated handle (CLAUDE.md, Concurrency): when the ViewModel goes away, the bag goes with it
/// and cancels them, which ends the streams. `stopListening()` cancels the same way on purpose.
final class TaskBag: Sendable {
    private let tasks = OSAllocatedUnfairLock<[Task<Void, Never>]>(initialState: [])

    var isEmpty: Bool { tasks.withLock { $0.isEmpty } }

    func add(_ new: [Task<Void, Never>]) {
        tasks.withLock { $0 += new }
    }

    func cancelAll() {
        let running = tasks.withLock { current -> [Task<Void, Never>] in
            defer { current = [] }
            return current
        }
        running.forEach { $0.cancel() }
    }

    deinit {
        cancelAll()
    }
}
