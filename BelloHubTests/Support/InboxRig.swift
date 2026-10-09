//
//  InboxRig.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation

/// A `BookingSyncService` and its `OutboundQueue` over a `FakeInboxRepository` and an in-memory vault, with isolated
/// defaults. No polling and no automatic retry (a test flushes the queue itself), so every wait is on a condition.
@MainActor
struct InboxRig {
    let sync: BookingSyncService
    let queue: OutboundQueue
    let repository: FakeInboxRepository
    let vault: VaultService
    let defaults: UserDefaults
    private let suite: String

    static let userID = "user-1"

    init(repository: FakeInboxRepository) {
        suite = "test.inbox.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite) ?? .standard
        self.repository = repository
        vault = VaultService(repository: InMemoryClientRecordRepository())
        queue = OutboundQueue(
            repository: repository, defaults: defaults, now: { TestClock.now }, retryDelays: [.seconds(600)],
            sleeper: { try await Task.sleep(for: $0) }
        )
        sync = BookingSyncService(
            repository: repository, queue: queue, appointments: AppointmentService(vault: vault), vault: vault,
            defaults: defaults, now: { TestClock.now }, pollInterval: nil
        )
    }

    /// Starts the session and waits for the first sync.
    func start() async {
        sync.startListening(userId: Self.userID)
        await Wait.untilMain { !sync.isLoading && !sync.isSyncing }
    }

    func cleanUp() {
        sync.stopListening()
        defaults.removePersistentDomain(forName: suite)
    }
}
