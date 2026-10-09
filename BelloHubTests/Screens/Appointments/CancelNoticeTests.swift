//
//  CancelNoticeTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@Suite("CancelNotice")
struct CancelNoticeTests {
    private let start = TestClock.date("2026-10-02 12:00")
    private var policy: CancellationPolicy { CancellationPolicy.standard }

    private func notice(
        by who: CancelledBy, hoursBefore: Double, noShow: NoShowPolicy = .standard
    ) -> CancelNotice {
        CancelNotice.make(
            by: who, policy: policy, noShow: noShow, startsAt: start,
            now: start.addingTimeInterval(-hoursBefore * 3600)
        )
    }

    @Test("A cancellation by the professional never counts, however late (D13)", arguments: [0.5, 5.0, 24.0, 100.0])
    func professional(hours: Double) {
        let result = notice(by: .professional, hoursBefore: hours)

        #expect(result == .byProfessional)
        #expect(!result.isLate && !result.countsAgainstClient)
    }

    @Test("A client who cancels at the edge of the free window is in time; one minute later she is late")
    func theBoundary() {
        #expect(notice(by: .client, hoursBefore: 24) == .clientInTime(freeWindowHours: 24))
        #expect(notice(by: .client, hoursBefore: 23.98) == .clientLate(freeWindowHours: 24, counts: false))
    }

    @Test("A late cancellation counts only when the rule is on and counts late cancellations")
    func countsOnlyWhenTheRuleSaysSo() {
        var counting = NoShowPolicy.standard
        counting.lateCancelCounts = true
        var off = counting
        off.isOn = false

        #expect(notice(by: .client, hoursBefore: 2, noShow: counting).countsAgainstClient)
        #expect(!notice(by: .client, hoursBefore: 2, noShow: .standard).countsAgainstClient)
        #expect(!notice(by: .client, hoursBefore: 2, noShow: off).countsAgainstClient)
        #expect(notice(by: .client, hoursBefore: 2, noShow: off).isLate)
    }

    @Test("The window follows the policy of the visit, not a fixed 24 hours")
    func followsThePolicy() {
        var strict = policy
        strict.freeWindowHours = 72
        let result = CancelNotice.make(
            by: .client, policy: strict, noShow: .standard, startsAt: start, now: start.addingTimeInterval(-48 * 3600)
        )

        #expect(result == .clientLate(freeWindowHours: 72, counts: false))
    }
}
