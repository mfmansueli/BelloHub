//
//  FakePublishingSource.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation

/// What `PublishingService` reads, in a test: the inputs are a value the test edits, and `fireChange()` plays
/// "something changed in her vault".
@MainActor
final class FakePublishingSource: PublishingSource {
    var value: PublishInputs
    var error: (any Error)?
    private(set) var readCount = 0
    private var continuations: [AsyncStream<Void>.Continuation] = []

    /// How many times the service subscribed to the changes (it does so in a task, a moment after `start`).
    var subscriptions: Int { continuations.count }

    init(_ value: PublishInputs = makePublishInputs()) {
        self.value = value
    }

    func inputs(now: Date) async throws -> PublishInputs {
        readCount += 1
        if let error { throw error }
        return value
    }

    func changes() -> AsyncStream<Void> {
        let (stream, continuation) = AsyncStream<Void>.makeStream()
        continuations.append(continuation)
        return stream
    }

    /// Plays one vault change.
    func fireChange() {
        continuations.forEach { $0.yield() }
    }

    func update(_ edit: (inout PublishInputs) -> Void) {
        edit(&value)
    }
}
