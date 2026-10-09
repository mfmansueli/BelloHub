//
//  NoShowHistoryBuilderTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@Suite("NoShowHistoryBuilder")
struct NoShowHistoryBuilderTests {
    private let calendar = TestClock.calendar()
    private let client = makeClient()
    private var policy: NoShowPolicy { NoShowPolicy.standard }

    private func entries(_ appointments: [Appointment], policy: NoShowPolicy? = nil, client: Client? = nil)
        -> [NoShowHistoryEntry] {
        NoShowHistoryBuilder.entries(
            policy: policy ?? self.policy, client: client ?? self.client, appointments: appointments,
            now: TestClock.now, calendar: calendar
        )
    }

    private func noShow(_ daysAgo: Int, forgiven: Bool = false) -> Appointment {
        makeAppointment(clientID: client.id, daysFromNow: -daysAgo, status: .noShow, forgiven: forgiven)
    }

    private func lateCancel(_ daysAgo: Int) -> Appointment {
        makeAppointment(
            clientID: client.id, daysFromNow: -daysAgo, status: .cancelled, cancelledBy: .client, isLate: true
        )
    }

    @Test("Only misses and late cancellations by the client are listed, newest first")
    func listsTheRightVisits() {
        let completed = makeAppointment(clientID: client.id, daysFromNow: -5)
        let byProfessional = makeAppointment(
            clientID: client.id, daysFromNow: -6, status: .cancelled, cancelledBy: .professional, isLate: false
        )
        let inTime = makeAppointment(
            clientID: client.id, daysFromNow: -7, status: .cancelled, cancelledBy: .client, isLate: false
        )
        let result = entries([noShow(30), completed, byProfessional, inTime, noShow(10), lateCancel(20)])

        #expect(result.map(\.kind) == [.noShow, .lateCancellation, .noShow])
        #expect(result.map(\.startsAt) == result.map(\.startsAt).sorted(by: >))
    }

    @Test("A miss counts, a forgiven one is forgiven, an old one has expired")
    func standings() {
        let result = entries([noShow(10), noShow(20, forgiven: true), noShow(400)])

        #expect(result.map(\.standing) == [.counts, .forgiven, .expired])
    }

    @Test("A late cancellation counts only if the rule counts them")
    func lateCancellationStanding() {
        var counting = policy
        counting.lateCancelCounts = true

        #expect(entries([lateCancel(10)]).first?.standing == .notCounted)
        #expect(entries([lateCancel(10)], policy: counting).first?.standing == .counts)
    }

    @Test("Starting the count again expires what came before, and keeps it in the list")
    func afterAReset() {
        var reset = client
        reset.noShowCountResetAt = TestClock.days(-15)
        let result = entries([noShow(10), noShow(20)], client: reset)

        #expect(result.map(\.standing) == [.counts, .expired])
    }

    @Test("Only a miss that is not already forgiven can be forgiven")
    func canForgive() {
        let result = entries([noShow(10), noShow(20, forgiven: true), lateCancel(30)])

        #expect(result.map(\.canForgive) == [true, false, false])
    }

    @Test("Another client's visits are not listed")
    func otherClients() {
        let stranger = makeAppointment(clientID: UUID(), daysFromNow: -3, status: .noShow)

        #expect(entries([stranger]).isEmpty)
    }
}
