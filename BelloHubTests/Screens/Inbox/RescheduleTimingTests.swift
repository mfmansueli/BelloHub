//
//  RescheduleTimingTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@Suite("RescheduleTiming")
struct RescheduleTimingTests {
    @Test("Asked 19 hours before with a 24-hour window is late; 30 hours before is not")
    func lateOrNot() {
        let late = RescheduleTiming.make(request: makeRescheduleRequest(hoursBefore: 19), policy: .standard)
        #expect(late.minutesBefore == 19 * 60 && late.freeWindowHours == 24 && late.isLate)
        let early = RescheduleTiming.make(request: makeRescheduleRequest(hoursBefore: 30), policy: .standard)
        #expect(!early.isLate)
    }

    @Test("Exactly at the window's edge is not late")
    func edge() {
        #expect(!RescheduleTiming.make(request: makeRescheduleRequest(hoursBefore: 24), policy: .standard).isLate)
    }

    @Test("Without her rules nothing is called late, and a request after the start counts as zero minutes")
    func noPolicyAndClamp() {
        #expect(!RescheduleTiming.make(request: makeRescheduleRequest(hoursBefore: 1), policy: nil).isLate)
        #expect(RescheduleTiming.make(request: makeRescheduleRequest(hoursBefore: -2), policy: .standard)
            .minutesBefore == 0)
    }
}
