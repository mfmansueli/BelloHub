//
//  SubscriptionSnapshotTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@Suite("SubscriptionSnapshot")
struct SubscriptionSnapshotTests {
    private let active = SubscriptionState.active(period: .yearly, expiresAt: TestClock.days(10), willRenew: true)

    @Test("Offline, a proven plan lasts until its signed end and not a second more")
    func untilSignedEnd() {
        let snapshot = SubscriptionSnapshot(state: active, seenAt: TestClock.now)
        #expect(snapshot.state(at: TestClock.days(9)) == active)
        #expect(snapshot.state(at: TestClock.days(10)) == .none)
        #expect(snapshot.state(at: TestClock.days(40)) == .none)
    }

    @Test("Turning the clock back never stretches a plan past what this iPhone has already seen")
    func clockBack() {
        let seen = SubscriptionSnapshot(state: active, seenAt: TestClock.now).seen(at: TestClock.days(11))
        #expect(seen.state(at: TestClock.days(1)) == .none, "the clock was moved back after the end was seen")
        #expect(seen.seen(at: TestClock.days(2)).latestSeenAt == TestClock.days(11), "time seen only moves forward")
    }

    @Test("A clock moved forward only ends the plan early; it never adds time")
    func clockForward() {
        let snapshot = SubscriptionSnapshot(state: active, seenAt: TestClock.now)
        #expect(snapshot.state(at: TestClock.days(20)) == .none)
    }

    @Test("Grace keeps its kind; no plan, or a plan with no signed end, is not trusted offline")
    func kinds() {
        let grace = SubscriptionState.inGracePeriod(period: .monthly, expiresAt: TestClock.days(3))
        #expect(SubscriptionSnapshot(state: grace, seenAt: TestClock.now).state(at: TestClock.now) == grace)
        #expect(SubscriptionSnapshot(state: .none, seenAt: TestClock.now).state(at: TestClock.now) == .none)
        let noEnd = SubscriptionState.active(period: .monthly, expiresAt: nil, willRenew: true)
        #expect(SubscriptionSnapshot(state: noEnd, seenAt: TestClock.now).state(at: TestClock.now) == .none)
    }

    @Test("It round-trips through JSON")
    func coding() throws {
        let snapshot = SubscriptionSnapshot(state: active, seenAt: TestClock.now)
        let decoded = try JSONDecoder().decode(SubscriptionSnapshot.self, from: JSONEncoder().encode(snapshot))
        #expect(decoded == snapshot)
    }
}
