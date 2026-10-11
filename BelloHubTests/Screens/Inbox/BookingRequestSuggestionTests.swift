//
//  BookingRequestSuggestionTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

/// "Suggest another time" on 2.10: the server declines the request and holds the proposed time; the screen gives the
/// link to send; a time that is not free, or no network, says so and changes nothing.
@MainActor
@Suite("BookingRequestViewModel: suggest another time")
struct BookingRequestSuggestionTests {
    private func makeModel() async -> (BookingRequestViewModel, InboxRig) {
        let booking = makeIncomingBooking(reason: .newClient)
        let rig = InboxRig(repository: FakeInboxRepository(bookings: [booking]))
        await rig.start()
        let model = BookingRequestViewModel(
            bookingID: booking.id, sync: rig.sync, vault: rig.vault, link: BookingLink(slug: "maria"),
            now: { TestClock.now }
        )
        return (model, rig)
    }

    @Test("The suggestion is sent with the chosen start, the request reads declined and the link holds the key")
    func suggests() async throws {
        let (model, rig) = await makeModel()
        defer { rig.cleanUp() }
        let original = try #require(model.booking?.startsAt)

        model.beginSuggestion()
        #expect(model.isSuggestSheetPresented)
        #expect(model.suggestedStart == original.addingTimeInterval(86_400), "a day later as the starting point")
        await model.suggestAsync()

        let sent = "suggestBookingTime:bk-1:\(CallableJSON.instant(model.suggestedStart))"
        #expect(await rig.repository.writes == [sent])
        #expect(model.booking?.status == .declined)
        let url = try #require(model.suggestionURL)
        #expect(url.path() == "/maria/time")
        #expect(url.query()?.contains("offer=held") == true)
        #expect(model.suggestionErrorMessage == nil)
    }

    @Test("A time that is not free asks for another one and leaves the request open")
    func slotTaken() async {
        let (model, rig) = await makeModel()
        defer { rig.cleanUp() }
        await rig.repository.setSuggestionOutcome(.slotTaken)

        model.beginSuggestion()
        await model.suggestAsync()

        #expect(model.suggestionURL == nil)
        #expect(model.suggestionErrorMessage != nil)
        #expect(model.phase == .open)
    }

    @Test("Offline the suggestion fails and says so; nothing is queued")
    func offline() async {
        let (model, rig) = await makeModel()
        defer { rig.cleanUp() }
        await rig.repository.setWriteFailure(.unreachable)

        model.beginSuggestion()
        await model.suggestAsync()

        #expect(model.suggestionErrorMessage != nil)
        #expect(rig.queue.pending.isEmpty)
        #expect(model.phase == .open)
    }

    @Test("A start in the past is not sent")
    func pastStart() async {
        let (model, rig) = await makeModel()
        defer { rig.cleanUp() }
        model.beginSuggestion()
        model.suggestedStart = TestClock.now.addingTimeInterval(-3_600)

        await model.suggestAsync()

        #expect(await rig.repository.writes.isEmpty)
    }

    @Test("The starting point is the same wall-clock time a day later, also across a daylight-saving change")
    func dayLaterInBusinessZone() async throws {
        var booking = makeIncomingBooking(reason: .newClient)
        booking.timeZoneID = "Europe/Lisbon"
        booking.startsAt = TestClock.date("2026-10-24 10:00", zone: "Europe/Lisbon")
        booking.endsAt = booking.startsAt.addingTimeInterval(5_400)
        let rig = InboxRig(repository: FakeInboxRepository(bookings: [booking]))
        await rig.start()
        defer { rig.cleanUp() }
        let model = BookingRequestViewModel(
            bookingID: booking.id, sync: rig.sync, vault: rig.vault, link: BookingLink(slug: "maria"),
            now: { TestClock.now }
        )
        model.beginSuggestion()
        // Sunday 25 October is 25 hours long in Lisbon: 24 hours later would be 09:00.
        #expect(model.suggestedStart == TestClock.date("2026-10-25 10:00", zone: "Europe/Lisbon"))
    }
}
