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
        #expect(model.results["a"] == .offered(until: TestClock.now))
        #expect(model.board(now: TestClock.now).offerable.map(\.id) == ["b"], "an offered person is not offerable")
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
