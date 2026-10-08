//
//  RecordLockPolicyTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@Suite("RecordLockPolicy")
struct RecordLockPolicyTests {
    private let created = TestClock.date("2026-09-30 17:42")

    @Test("A record is editable until 24 hours and needs a correction after (23:59:59 vs 24:00:00)")
    func lockBoundary() {
        let lockedAt = RecordLockPolicy.lockedAt(createdAt: created)

        #expect(RecordLockPolicy.editPath(lockedAt: lockedAt, now: created) == .editDirectly)
        #expect(RecordLockPolicy.editPath(lockedAt: lockedAt, now: lockedAt.addingTimeInterval(-1)) == .editDirectly)
        #expect(RecordLockPolicy.editPath(lockedAt: lockedAt, now: lockedAt) == .addCorrection)
        #expect(RecordLockPolicy.editPath(lockedAt: lockedAt, now: lockedAt.addingTimeInterval(1)) == .addCorrection)
    }

    @Test("The lock is exactly 24 real hours after creation")
    func lockedAtIsTwentyFourHours() {
        #expect(RecordLockPolicy.lockedAt(createdAt: created).timeIntervalSince(created) == 86_400)
    }

    @Test("A daylight-saving change does not stretch or shrink the lock")
    func lockIgnoresDaylightSaving() {
        // Lisbon springs forward on 2026-03-29 at 01:00 UTC: a calendar day would be 23 hours long.
        let before = TestClock.date("2026-03-28 12:00", zone: "Europe/Lisbon")

        #expect(RecordLockPolicy.lockedAt(createdAt: before).timeIntervalSince(before) == 86_400)
    }

    @Test("Time remaining counts down and disappears once locked")
    func remaining() {
        let lockedAt = RecordLockPolicy.lockedAt(createdAt: created)

        #expect(RecordLockPolicy.remaining(lockedAt: lockedAt, now: created.addingTimeInterval(3_600)) == 82_800)
        #expect(RecordLockPolicy.remaining(lockedAt: lockedAt, now: lockedAt) == nil)
    }

    @Test("A new treatment record gets its lock time from the policy")
    func recordCarriesTheLock() {
        let record = TreatmentRecord(clientID: UUID(), serviceName: "Glow Facial", createdAt: created)

        #expect(record.lockedAt == created.addingTimeInterval(86_400))
    }
}
