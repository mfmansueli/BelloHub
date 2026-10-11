//
//  FollowUpQueueServiceTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@Suite("FollowUpQueueService")
@MainActor
struct FollowUpQueueServiceTests {
    @Test("Decisions and visit closings are kept per user and come back after a relaunch")
    func persists() throws {
        let suite = "queue-service-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let vault = VaultService(repository: InMemoryClientRecordRepository())
        let first = FollowUpQueueService(defaults: defaults, vault: vault, now: { TestClock.now })
        first.start(userID: "maria")
        first.snooze("returnDue:a")
        first.markSent("notBack:b")
        let closing = VisitClosing(id: UUID(), clientID: UUID(), serviceName: "Glow", recordCreatedAt: TestClock.now)
        first.save(closing)

        let again = FollowUpQueueService(defaults: defaults, vault: vault, now: { TestClock.now })
        again.start(userID: "maria")
        #expect(again.decisions["returnDue:a"]?.snoozedUntil == TestClock.days(7))
        #expect(again.decisions["notBack:b"]?.markedSentAt == TestClock.now)
        #expect(again.closing(for: closing.id) == closing)

        let other = FollowUpQueueService(defaults: defaults, vault: vault, now: { TestClock.now })
        other.start(userID: "someone-else")
        #expect(other.decisions.isEmpty && other.closings.isEmpty)

        again.complete(recordID: closing.id)
        #expect(again.closing(for: closing.id)?.isComplete == true)
        again.restore("returnDue:a")
        #expect(again.decisions["returnDue:a"] == nil)
        again.stop()
        #expect(again.decisions.isEmpty)
    }
}
