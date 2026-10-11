//
//  WaitlistViewModelTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@MainActor
@Suite("WaitlistViewModel")
struct WaitlistViewModelTests {
    private let cancelled = makeIncomingBooking(id: "bk-c", status: .cancelledByClient, daysAhead: 3, hour: 15)

    private func makeModel(
        waitlist: [WaitlistRequest] = [makeWaitlistRequest(id: "a", daysAgo: 5), makeWaitlistRequest(id: "b")]
    ) async -> (WaitlistViewModel, InboxRig) {
        let rig = InboxRig(repository: FakeInboxRepository(bookings: [cancelled], waitlist: waitlist))
        await rig.start()
        return (WaitlistViewModel(sync: rig.sync, timeZone: TestClock.saoPaulo), rig)
    }

    @Test("Offering sends the open time's service and start, and the person shows as offered")
    func offer() async throws {
        let (model, rig) = await makeModel()
        defer { rig.cleanUp() }
        let entry = try #require(model.board(now: TestClock.now).offerable.first)
        await model.offerAsync(entry, now: TestClock.now)
        let sent = try #require(await rig.repository.offers.first)
        #expect(sent.waitlistId == "a" && sent.serviceId == "svc-glow" && sent.startsAt == cancelled.startsAt)
        #expect(model.results["a"] == .offered(until: TestClock.now, holdKey: "hold"))
        #expect(model.board(now: TestClock.now).offerable.map(\.id) == ["b"], "an offered person is not offerable")
    }

    @Test("Send opens WhatsApp with the offer and its one-time link, after the server held the time")
    func sendOffer() async throws {
        let repository = FakeInboxRepository(bookings: [cancelled], waitlist: [makeWaitlistRequest(id: "a")])
        let rig = InboxRig(repository: repository)
        await rig.start()
        defer { rig.cleanUp() }
        let sender = FakeMessageSender()
        let log = InMemoryClientRecordRepository(clock: { TestClock.now })
        let model = WaitlistViewModel(
            sync: rig.sync, timeZone: TestClock.saoPaulo, messages: MessageService(repository: log, sender: sender),
            link: BookingLink(slug: "maria"), business: AgendaBusinessContext(profile: nil), now: { TestClock.now }
        )
        let entry = try #require(model.board(now: TestClock.now).offerable.first)
        #expect(model.offerText(for: entry, now: TestClock.now) == nil, "nothing to send before the server held it")
        await model.offerAsync(entry, now: TestClock.now)
        let text = try #require(model.offerText(for: entry, now: TestClock.now))
        #expect(text.hasSuffix("\nhttps://bellohub.app/maria/time?offer=hold"))
        await model.sendAsync(entry)
        let opened = try #require(sender.opened.first?.absoluteString)
        #expect(opened.hasPrefix("https://wa.me/551190001?text="))
        #expect(opened.contains(MessageLinks.encoded("https://bellohub.app/maria/time?offer=hold")))
        #expect(model.sent.contains("a") && model.shareText == nil)
    }

    @Test("Offer to everyone reaches everybody waiting for that day, oldest first")
    func offerAll() async {
        let (model, rig) = await makeModel()
        defer { rig.cleanUp() }
        await model.offerAllAsync(now: TestClock.now)
        #expect(await rig.repository.offers.map(\.waitlistId) == ["a", "b"])
    }

    @Test("When the time is taken, the offers stop and the screen says so")
    func slotTaken() async {
        let (model, rig) = await makeModel()
        defer { rig.cleanUp() }
        await rig.repository.setOfferOutcome(.slotTaken)
        await model.offerAllAsync(now: TestClock.now)
        #expect(await rig.repository.offers.map(\.waitlistId) == ["a"])
        #expect(model.isTimeTaken)
    }

    @Test("Offline, an offer fails with a message and nothing is marked offered")
    func offline() async throws {
        let (model, rig) = await makeModel()
        defer { rig.cleanUp() }
        await rig.repository.setWriteFailure(.unreachable)
        let entry = try #require(model.board(now: TestClock.now).offerable.first)
        await model.offerAsync(entry, now: TestClock.now)
        #expect(model.errorMessage != nil && model.results.isEmpty && model.offering.isEmpty)
        model.dismissError()
        #expect(model.errorMessage == nil)
    }

    @Test("Removing somebody takes them off the list at once and tells the server")
    func remove() async throws {
        let (model, rig) = await makeModel()
        defer { rig.cleanUp() }
        let entry = try #require(model.board(now: TestClock.now).forThatDay.first)
        model.remove(entry)
        #expect(model.board(now: TestClock.now).forThatDay.map(\.id) == ["b"])
        let repository = rig.repository
        #expect(await Wait.until { await repository.writes == ["removeWaitlistEntry:a"] })
    }
}
