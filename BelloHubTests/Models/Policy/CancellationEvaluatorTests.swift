//
//  CancellationEvaluatorTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@Suite("CancellationEvaluator")
struct CancellationEvaluatorTests {
    private let startsAt = TestClock.date("2026-10-15 15:00")
    private let standard = CancellationPolicy.standard

    private func decide(
        _ policy: CancellationPolicy, hoursBefore: Double, reschedules: Int = 0
    ) -> CancellationDecision {
        let now = startsAt.addingTimeInterval(-hoursBefore * 3_600)

        return CancellationEvaluator.decide(policy: policy, startsAt: startsAt, now: now, rescheduleCount: reschedules)
    }

    @Test("Free up to and including the boundary: exactly 24 hours before is still inside a 24-hour window",
          arguments: [(48.0, true), (24.0, true), (23.99, false), (2.0, false), (0.5, false)])
    func freeWindowBoundary(hours: Double, inside: Bool) {
        let decision = decide(standard, hoursBefore: hours)

        #expect(decision.isInsideFreeWindow == inside)
        #expect(decision.cancel == (inside ? .free : .allowedWithWarning))
    }

    @Test("Every free-window option from the policy behaves the same way",
          arguments: CancellationPolicy.freeWindowOptions)
    func windowOptions(hours: Int) {
        var policy = standard
        policy.freeWindowHours = hours

        #expect(decide(policy, hoursBefore: Double(hours)).isInsideFreeWindow)
        #expect(!decide(policy, hoursBefore: Double(hours) - 0.1).isInsideFreeWindow)
    }

    @Test("After the window the client may cancel with an honest warning, or must message her")
    func afterWindowCancel() {
        var policy = standard
        #expect(decide(policy, hoursBefore: 3).cancel == .allowedWithWarning)
        #expect(decide(policy, hoursBefore: 3).cancellationWouldBeLate)

        policy.afterWindowCancel = .message
        #expect(decide(policy, hoursBefore: 3).cancel == .askByMessage)
        #expect(!decide(policy, hoursBefore: 3).cancellationWouldBeLate)
    }

    @Test("Rescheduling: direct inside the window, a request or a message after it")
    func rescheduleModes() {
        var policy = standard
        #expect(decide(policy, hoursBefore: 30).reschedule == .direct)
        #expect(decide(policy, hoursBefore: 10).reschedule == .request)

        policy.afterWindowReschedule = .message
        #expect(decide(policy, hoursBefore: 10).reschedule == .message)
        #expect(decide(policy, hoursBefore: 30).reschedule == .direct)
    }

    @Test("Clients who may not reschedule always message, and the maximum number of moves is respected")
    func rescheduleLimits() {
        var policy = standard
        policy.clientCanReschedule = false
        #expect(decide(policy, hoursBefore: 100).reschedule == .message)

        policy.clientCanReschedule = true
        policy.maxReschedules = 2
        #expect(decide(policy, hoursBefore: 100, reschedules: 1).reschedule == .direct)
        #expect(decide(policy, hoursBefore: 100, reschedules: 2).reschedule == .message)

        policy.maxReschedules = nil
        #expect(decide(policy, hoursBefore: 100, reschedules: 50).reschedule == .direct)
    }

    @Test("A visit that has started or passed can be neither cancelled nor moved by the client")
    func startedVisit() {
        #expect(decide(standard, hoursBefore: 0).cancel == .unavailable)
        #expect(decide(standard, hoursBefore: -3).reschedule == .unavailable)
    }

    @Test("A late cancellation is one made inside the free window")
    func lateCancellation() {
        let early = startsAt.addingTimeInterval(-25 * 3_600)
        let late = startsAt.addingTimeInterval(-23 * 3_600)

        #expect(!CancellationEvaluator.isLateCancellation(policy: standard, startsAt: startsAt, cancelledAt: early))
        #expect(CancellationEvaluator.isLateCancellation(policy: standard, startsAt: startsAt, cancelledAt: late))
    }

    @Test("The time is held for the grace period after the start")
    func grace() {
        #expect(CancellationEvaluator.graceDeadline(policy: standard, startsAt: startsAt)
            == startsAt.addingTimeInterval(15 * 60))
    }

    @Test("The prototype's defaults are 24 hours, two reschedules, cancelling allowed with a warning, 15 minutes")
    func standardPolicy() {
        #expect(standard.freeWindowHours == 24)
        #expect(standard.maxReschedules == 2)
        #expect(standard.afterWindowCancel == .allow)
        #expect(standard.graceMinutes == 15)
        #expect(CancellationPolicy.graceRange.contains(standard.graceMinutes))
    }
}
