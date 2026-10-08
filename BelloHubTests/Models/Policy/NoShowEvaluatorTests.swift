//
//  NoShowEvaluatorTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@Suite("NoShowEvaluator")
struct NoShowEvaluatorTests {
    private let calendar = TestClock.calendar()
    private let client = makeClient()
    private var policy: NoShowPolicy { NoShowPolicy.standard }

    private func status(
        _ appointments: [Appointment], policy: NoShowPolicy? = nil, client: Client? = nil
    ) -> NoShowStatus {
        NoShowEvaluator.status(policy: policy ?? self.policy, client: client ?? self.client,
                               appointments: appointments, now: TestClock.now, calendar: calendar)
    }

    private func noShow(_ daysAgo: Int, forgiven: Bool = false) -> Appointment {
        makeAppointment(clientID: client.id, daysFromNow: -daysAgo, status: .noShow, forgiven: forgiven)
    }

    @Test("The limit is reached at exactly the limit, and the policy's action applies then")
    func limitReached() {
        let two = status([noShow(10), noShow(20)])
        let three = status([noShow(10), noShow(20), noShow(30)])

        #expect(two.counted == 2 && !two.limitReached && two.remainingBeforeLimit == 1)
        #expect(three.limitReached && three.remainingBeforeLimit == 0)
        #expect(NoShowEvaluator.actionToApply(policy: policy, status: two) == nil)
        #expect(NoShowEvaluator.actionToApply(policy: policy, status: three) == .tell)
    }

    @Test("The action follows the policy", arguments: NoShowAction.allCases)
    func action(action: NoShowAction) {
        var custom = policy
        custom.action = action
        custom.limit = 1
        let result = status([noShow(5)], policy: custom)

        #expect(NoShowEvaluator.actionToApply(policy: custom, status: result) == action)
    }

    @Test("A cancellation by the professional never counts, even with late cancellations counted")
    func professionalCancellationNeverCounts() {
        var counting = policy
        counting.lateCancelCounts = true
        let byProfessional = makeAppointment(clientID: client.id, daysFromNow: -5, status: .cancelled,
                                             cancelledBy: .professional, isLate: true)

        #expect(status([byProfessional], policy: counting).counted == 0)
    }

    @Test("A forgiven no-show does not count")
    func forgiven() {
        #expect(status([noShow(10, forgiven: true), noShow(20)]).counted == 1)
    }

    @Test("A late cancellation by the client counts only when the policy says so")
    func lateCancelToggle() {
        let late = makeAppointment(clientID: client.id, daysFromNow: -5, status: .cancelled, cancelledBy: .client,
                                   isLate: true)
        let early = makeAppointment(clientID: client.id, daysFromNow: -6, status: .cancelled, cancelledBy: .client)
        var counting = policy
        counting.lateCancelCounts = true

        #expect(status([late, early]).counted == 0)
        #expect(status([late, early], policy: counting).counted == 1)
    }

    @Test("Old no-shows stop counting after the counting period", arguments: NoShowPolicy.countingMonthOptions)
    func countingPeriod(months: Int) {
        var custom = policy
        custom.countingMonths = months
        let oldEnough = months * 31 + 5

        #expect(status([noShow(oldEnough)], policy: custom).counted == 0)
        #expect(status([noShow(months * 28 - 5)], policy: custom).counted == 1)
    }

    @Test("Starting a client's count from zero ignores everything before that day, and the history stays")
    func resetCount() {
        let reset = TestClock.days(-15)
        let resetClient = makeClient(id: client.id, noShowCountResetAt: reset)
        let history = [noShow(10), noShow(20), noShow(30)]

        #expect(status(history, client: resetClient).counted == 1)
        #expect(status(history).counted == 3)
    }

    @Test("With protection off nothing is ever reached, though the count is still kept")
    func protectionOff() {
        var off = policy
        off.isOn = false
        let result = status([noShow(1), noShow(2), noShow(3), noShow(4)], policy: off)

        #expect(result.counted == 4)
        #expect(!result.limitReached)
        #expect(NoShowEvaluator.actionToApply(policy: off, status: result) == nil)
    }

    @Test("Other clients' no-shows and future visits are ignored")
    func scope() {
        let stranger = makeAppointment(clientID: UUID(), daysFromNow: -5, status: .noShow)
        let future = makeAppointment(clientID: client.id, daysFromNow: 5, status: .noShow)

        #expect(status([stranger, future]).counted == 0)
    }

    @Test("The default is protection on, three allowed, only tell the professional")
    func defaults() {
        #expect(policy.isOn && policy.limit == 3 && policy.action == .tell && !policy.lateCancelCounts)
        #expect(NoShowPolicy.limitRange.contains(policy.limit))
    }
}
