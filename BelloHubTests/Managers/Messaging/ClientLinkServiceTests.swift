//
//  ClientLinkServiceTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@MainActor
@Suite("ClientLinkService")
struct ClientLinkServiceTests {
    private let page = BookingLink(slug: "maria")

    private func visit(bookingID: String? = "bk-1") -> Appointment {
        let start = TestClock.now.addingTimeInterval(86_400)
        var appointment = Appointment(
            clientID: UUID(), serviceName: "Facial", startsAt: start, endsAt: start.addingTimeInterval(3600),
            totalMinutes: 60, status: .booked, createdAt: TestClock.days(-3)
        )
        appointment.bookingID = bookingID
        return appointment
    }

    @Test("The minted link is kept for a while: a second message does not ask the server again")
    func reusesMintedLink() async throws {
        let inbox = FakeInboxRepository()
        let service = ClientLinkService(repository: inbox, now: { TestClock.now })

        let first = await service.choice(for: visit(), bookingPage: page)
        let second = await service.choice(for: visit(), bookingPage: page)

        #expect(first.source == .manageLink && first == second)
        #expect(try #require(first.link).hasPrefix("https://bellohub.app/m/"))
        #expect(await inbox.writes == ["mintManageLink:bk-1"])
        service.clear()
        _ = await service.choice(for: visit(), bookingPage: page)
        #expect(await inbox.writes.count == 2, "a cleared session asks again")
    }

    @Test("Offline and refused calls fall back to the booking page with their reason", arguments: [
        (BookingRepositoryError.unreachable, ClientLinkChoice.Reason.offline),
        (.notPublishedYet, .offline),
        (.rejected, .failed),
        (.busy, .failed)
    ])
    func fallbacks(error: BookingRepositoryError, reason: ClientLinkChoice.Reason) async {
        let inbox = FakeInboxRepository()
        await inbox.setWriteFailure(error)
        let service = ClientLinkService(repository: inbox, now: { TestClock.now })

        let choice = await service.choice(for: visit(), bookingPage: page)

        #expect(choice == ClientLinkChoice(source: .bookingPage(reason), link: "https://bellohub.app/maria"))
    }

    @Test("Without a booking page and without a personal link there is no link at all")
    func noLink() async {
        let service = ClientLinkService(repository: FakeInboxRepository(), now: { TestClock.now })
        let choice = await service.choice(for: visit(bookingID: nil), bookingPage: nil)
        #expect(choice == ClientLinkChoice(source: .bookingPage(.addedByHand), link: nil))
    }
}
