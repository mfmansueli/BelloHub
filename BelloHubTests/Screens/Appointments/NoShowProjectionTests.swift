//
//  NoShowProjectionTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@Suite("NoShowProjection")
struct NoShowProjectionTests {
    private let calendar = TestClock.calendar()
    private let client = makeClient()

    private func noShow(_ daysAgo: Int, forgiven: Bool = false) -> Appointment {
        makeAppointment(clientID: client.id, daysFromNow: -daysAgo, status: .noShow, forgiven: forgiven)
    }

    private func projection(
        existing: [Appointment], marking: Appointment? = nil, policy: NoShowPolicy = .standard
    ) -> NoShowProjection {
        let target = marking ?? makeAppointment(clientID: client.id, daysFromNow: 0, hour: 9, status: .booked)
        return NoShowProjection.make(
            NoShowProjection.Input(policy: policy, client: client, appointments: existing + [target], marking: target),
            now: TestClock.now, calendar: calendar
        )
    }

    @Test("Marking one adds one to the count; the visit is not counted before it is marked")
    func addsOne() {
        let result = projection(existing: [noShow(10)])

        #expect(result.before.counted == 1)
        #expect(result.after.counted == 2)
        #expect(!result.reachesLimit)
    }

    @Test("The one that takes her to the limit says so")
    func reachesTheLimit() {
        let result = projection(existing: [noShow(10), noShow(20)])

        #expect(result.after.limitReached)
        #expect(result.reachesLimit)
        #expect(result.action == .tell)
    }

    @Test("A client already at the limit does not 'reach' it again")
    func alreadyAtTheLimit() {
        let result = projection(existing: [noShow(10), noShow(20), noShow(30)])

        #expect(result.before.limitReached)
        #expect(!result.reachesLimit)
    }

    @Test("Forgiven and old misses do not count")
    func forgivenAndOld() {
        let result = projection(existing: [noShow(10, forgiven: true), noShow(400)])

        #expect(result.before.counted == 0)
        #expect(result.after.counted == 1)
    }

    @Test("Marking a visit that is already a no-show does not count it twice")
    func idempotent() {
        let already = noShow(1)
        let result = projection(existing: [], marking: already)

        #expect(result.before.counted == 1)
        #expect(result.after.counted == 1)
    }

    @Test("With protection off nothing reaches a limit")
    func protectionOff() {
        var off = NoShowPolicy.standard
        off.isOn = false
        let result = projection(existing: [noShow(10), noShow(20)], policy: off)

        #expect(!result.after.limitReached && !result.reachesLimit)
    }
}
