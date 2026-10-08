//
//  LockPolicyTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@Suite("LockPolicy")
struct LockPolicyTests {
    private let now = TestClock.now

    @Test("A short absence stays open and a long one locks, at the exact boundary")
    func grace() {
        func locks(awayFor seconds: TimeInterval) -> Bool {
            LockPolicy.shouldLock(isEnabled: true, leftAt: now.addingTimeInterval(-seconds), now: now, graceSeconds: 60)
        }
        #expect(!locks(awayFor: 59))
        #expect(locks(awayFor: 60))
        #expect(locks(awayFor: 3_600))
    }

    @Test("A grace of zero locks the moment she leaves")
    func immediate() {
        #expect(LockPolicy.shouldLock(isEnabled: true, leftAt: now, now: now, graceSeconds: 0))
    }

    @Test("With the lock off nothing ever locks")
    func disabled() {
        let longAgo = now.addingTimeInterval(-9_999)
        #expect(!LockPolicy.shouldLock(isEnabled: false, leftAt: longAgo, now: now, graceSeconds: 0))
    }

    @Test("No recorded departure locks, and so does a clock that moved backwards")
    func unknownOrBackwards() {
        #expect(LockPolicy.shouldLock(isEnabled: true, leftAt: nil, now: now, graceSeconds: 900))
        let future = now.addingTimeInterval(120)
        #expect(LockPolicy.shouldLock(isEnabled: true, leftAt: future, now: now, graceSeconds: 900))
    }

    @Test("A stored grace that is not an option falls back to the default")
    func normalizedGrace() {
        #expect(LockPolicy.normalizedGrace(300) == 300)
        #expect(LockPolicy.normalizedGrace(0) == 0)
        #expect(LockPolicy.normalizedGrace(45) == LockPolicy.defaultGraceSeconds)
        #expect(LockPolicy.normalizedGrace(nil) == LockPolicy.defaultGraceSeconds)
    }
}
