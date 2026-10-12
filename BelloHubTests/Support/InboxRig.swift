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
    /// The calendar writes the screens make, wired to `sync` as in the app.
    let appointments: AppointmentService
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
        appointments = AppointmentService(vault: vault)
        sync = BookingSyncService(
            repository: repository, queue: queue, appointments: appointments, vault: vault,
            defaults: defaults, now: { TestClock.now }, pollInterval: nil
        )
    }

    /// Starts the session and waits for the first sync. The wait is longer than the default: it is a precondition, and
    /// under the load of the whole Fast plan the first sync sometimes took more than 3 seconds, so a test went on with
    /// an empty inbox (the WaitlistViewModel and RescheduleRequestViewModel flakes of 2026-10-10).
    func start() async {
        sync.startListening(userId: Self.userID)
        await Wait.untilMain(timeout: .seconds(20)) { !sync.isLoading && !sync.isSyncing }
    }

    /// Every visit in the vault mirrored from `bookingID`, whatever its time.
    func visits(bookingID: String) async -> [Appointment] {
        let all = DateInterval(start: .distantPast, end: .distantFuture)
        let visits = (try? await vault.repository?.loadAppointments(in: all)) ?? []
        return visits.filter { $0.bookingID == bookingID }
    }

    func cleanUp() {
        sync.stopListening()
        defaults.removePersistentDomain(forName: suite)
    }
}
