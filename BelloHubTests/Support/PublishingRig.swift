//
//  PublishingRig.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation

/// A `PublishingService` wired to fakes. The debounce and the retry pauses are instant, so a test waits for conditions
/// only (never a fixed delay).
@MainActor
struct PublishingRig {
    let service: PublishingService
    let repository: FakeBookingRepository
    let source: FakePublishingSource
    let defaults: UserDefaults
    private let suite: String

    static let userID = "user-1"

    init(inputs: PublishInputs = makePublishInputs()) {
        suite = "test.publishing.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite) ?? .standard
        repository = FakeBookingRepository()
        source = FakePublishingSource(inputs)
        service = PublishingService(
            repository: repository, source: source, defaults: defaults, now: { TestClock.now },
            debounce: .zero, retryDelays: [.zero], sleeper: { _ in }
        )
    }

    /// Stops the service's tasks and removes the isolated defaults.
    func cleanUp() {
        service.clear()
        defaults.removePersistentDomain(forName: suite)
    }
}
