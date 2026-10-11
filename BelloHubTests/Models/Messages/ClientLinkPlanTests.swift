//
//  ClientLinkPlanTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@Suite("ClientLinkPlan")
struct ClientLinkPlanTests {
    private func visit(
        bookingID: String? = "bk-1", status: AppointmentStatus = .booked, startsIn hours: Double = 24
    ) -> Appointment {
        let start = TestClock.now.addingTimeInterval(hours * 3600)
        var appointment = Appointment(
            clientID: UUID(), serviceName: "Facial", startsAt: start, endsAt: start.addingTimeInterval(3600),
            totalMinutes: 60, status: status, createdAt: TestClock.days(-3)
        )
        appointment.bookingID = bookingID
        return appointment
    }

    @Test("A visit from the booking page that still holds its time asks for the client's own link")
    func manageLink() {
        #expect(ClientLinkPlan.request(for: visit(), now: TestClock.now) == .manageLink(bookingID: "bk-1"))
        // Still in progress: the visit has started but not ended.
        let started = visit(startsIn: -0.5)
        #expect(ClientLinkPlan.request(for: started, now: TestClock.now) == .manageLink(bookingID: "bk-1"))
    }

    @Test("A visit she added herself uses her booking page")
    func addedByHand() {
        #expect(ClientLinkPlan.request(for: visit(bookingID: nil), now: TestClock.now) == .bookingPage(.addedByHand))
        #expect(ClientLinkPlan.request(for: visit(bookingID: ""), now: TestClock.now) == .bookingPage(.addedByHand))
    }

    @Test("A cancelled or finished visit has nothing to change: booking page", arguments: [
        AppointmentStatus.cancelled, .completed, .noShow
    ])
    func notActive(status: AppointmentStatus) {
        #expect(ClientLinkPlan.request(for: visit(status: status), now: TestClock.now) == .bookingPage(.notActive))
    }

    @Test("A visit that already ended uses the booking page")
    func ended() {
        #expect(ClientLinkPlan.request(for: visit(startsIn: -2), now: TestClock.now) == .bookingPage(.notActive))
    }

    @Test("A minted link is reused for 25 minutes and never after it expired")
    func reuse() throws {
        let url = try #require(URL(string: "https://bellohub.app/m/AbCdEfGhIjKlMnOpQrStUv"))
        let link = ClientManageLink(url: url, expiresAt: TestClock.now.addingTimeInterval(3600))
        let fetched = TestClock.now
        #expect(ClientLinkPlan.canReuse(link, fetchedAt: fetched, now: fetched.addingTimeInterval(24 * 60)))
        #expect(!ClientLinkPlan.canReuse(link, fetchedAt: fetched, now: fetched.addingTimeInterval(25 * 60)))
        #expect(!ClientLinkPlan.canReuse(link, fetchedAt: fetched, now: fetched.addingTimeInterval(-60)))
        let expiring = ClientManageLink(url: url, expiresAt: TestClock.now.addingTimeInterval(60))
        #expect(!ClientLinkPlan.canReuse(expiring, fetchedAt: fetched, now: fetched.addingTimeInterval(120)))
    }

    @Test("Only a link that could exist but was not obtained is worth asking again")
    func retry() {
        #expect(ClientLinkChoice(source: .bookingPage(.offline), link: nil).canRetry)
        #expect(ClientLinkChoice(source: .bookingPage(.failed), link: nil).canRetry)
        #expect(!ClientLinkChoice(source: .bookingPage(.addedByHand), link: nil).canRetry)
        #expect(!ClientLinkChoice(source: .bookingPage(.notActive), link: nil).canRetry)
        #expect(!ClientLinkChoice(source: .manageLink, link: "https://x").canRetry)
    }
}
