//
//  BookingRequestViewModelTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@MainActor
@Suite("BookingRequestViewModel")
struct BookingRequestViewModelTests {
    private func makeModel(
        _ booking: IncomingBooking = makeIncomingBooking(reason: .noShowLimit)
    ) async -> (BookingRequestViewModel, InboxRig) {
        let rig = InboxRig(repository: FakeInboxRepository(bookings: [booking]))
        await rig.start()
        return (BookingRequestViewModel(bookingID: booking.id, sync: rig.sync, vault: rig.vault), rig)
    }

    @Test("Approving with the count reset sends the reset first, then the approval, and ends approved")
    func approveWithReset() async {
        let (model, rig) = await makeModel()
        defer { rig.cleanUp() }
        #expect(model.phase == .open && model.offersCountReset)
        model.resetsCount = true
        model.approve()
        #expect(model.phase == .sending, "the answer shows as on its way at once")
        #expect(await Wait.untilMain { model.phase == .accepted })
        #expect(await rig.repository.writes == [
            "resetNoShowCount:+5511981234410", "respondBookingRequest:bk-1:true"
        ])
    }

    @Test("The count is not reset when the switch is off or the request waits for another reason")
    func noReset() async {
        let (model, rig) = await makeModel(makeIncomingBooking(reason: .newClient))
        defer { rig.cleanUp() }
        #expect(!model.offersCountReset)
        model.resetsCount = true
        model.approve()
        #expect(await Wait.untilMain { model.phase == .accepted })
        #expect(await rig.repository.writes == ["respondBookingRequest:bk-1:true"])
    }

    @Test("Declining ends declined and nothing is approved")
    func decline() async {
        let (model, rig) = await makeModel()
        defer { rig.cleanUp() }
        model.decline()
        #expect(await Wait.untilMain { model.phase == .declined })
        #expect(await rig.repository.writes == ["respondBookingRequest:bk-1:false"])
        model.approve()
        #expect(await rig.repository.writes.count == 1, "a declined request cannot be approved again")
    }

    @Test("An approval that needs a plan offers the plans, and approving again after buying goes through (D42)")
    func needsPlan() async {
        let (model, rig) = await makeModel(makeIncomingBooking(reason: .freeRegistrationsUsed))
        defer { rig.cleanUp() }
        await rig.repository.setApprovalOutcome(.needsSubscription)
        model.approve()
        #expect(await Wait.untilMain { model.phase == .needsPlan })
        model.showPlans()
        #expect(model.isPaywallPresented)

        await rig.repository.setApprovalOutcome(.confirmed)
        model.approve()
        #expect(await Wait.untilMain { model.phase == .accepted })
    }

    @Test("With the plan active on this iPhone, a server that still says 'needs a plan' is explained, not sold again")
    func serverMissesPlan() async {
        let booking = makeIncomingBooking(reason: .freeRegistrationsUsed)
        let rig = InboxRig(repository: FakeInboxRepository(bookings: [booking]))
        defer { rig.cleanUp() }
        await rig.start()
        let plan = FakeSubscriptionStatus(hasActivePlan: true)
        let model = BookingRequestViewModel(bookingID: booking.id, sync: rig.sync, vault: rig.vault, subscription: plan)
        await rig.repository.setApprovalOutcome(.needsSubscription)

        model.approve()

        #expect(await Wait.untilMain { model.phase == .needsPlan })
        #expect(model.serverMissesPlan)
        plan.hasActivePlan = false
        #expect(!model.serverMissesPlan, "without a plan the paywall is the right answer")
    }

    @Test("Offline, the answer waits in the queue and reaches the server when the network is back")
    func offlineReplay() async {
        let (model, rig) = await makeModel()
        defer { rig.cleanUp() }
        await rig.repository.setWriteFailure(.unreachable)
        model.approve()
        #expect(await Wait.untilMain { model.isWaitingForNetwork })
        #expect(model.phase == .sending)
        #expect(rig.queue.pending.count == 1)

        await rig.repository.setWriteFailure(nil)
        rig.queue.flush()
        #expect(await Wait.untilMain { model.phase == .accepted })
        #expect(rig.queue.pending.isEmpty && !model.isWaitingForNetwork)
    }

    @Test("A refused answer is reported and the request can be answered again")
    func refused() async {
        let (model, rig) = await makeModel()
        defer { rig.cleanUp() }
        await rig.repository.setWriteFailure(.rejected)
        model.approve()
        #expect(await Wait.untilMain { model.errorMessage != nil })
        #expect(model.phase == .open)
    }

    @Test("An unknown booking is missing once the first sync is done")
    func missing() async {
        let rig = InboxRig(repository: FakeInboxRepository())
        defer { rig.cleanUp() }
        let model = BookingRequestViewModel(bookingID: "nope", sync: rig.sync, vault: rig.vault)
        #expect(model.phase == .loading)
        await rig.start()
        #expect(model.phase == .missing)
    }

    @Test("Her client with the same phone opens the no-show history")
    func historyClient() async throws {
        let (model, rig) = await makeModel()
        defer { rig.cleanUp() }
        let client = Client(name: "Ana Costa", phoneE164: "+5511981234410", createdAt: TestClock.now)
        let repository = try #require(rig.vault.repository)
        try await repository.save(client)
        await model.loadAsync()
        #expect(model.historyClientID == client.id)
    }

    @Test("An unverified request shows the badge instead of a guessed reason, and approving works as usual")
    func unverifiedRequest() async {
        var booking = makeIncomingBooking(reason: nil)
        booking.verification = "whatsapp"
        booking.reference = "K7M2P"
        let (model, rig) = await makeModel(booking)
        defer { rig.cleanUp() }
        #expect(model.unverifiedBadge?.reference == "K7M2P")
        #expect(!model.showsReason)
        model.approve()
        #expect(await Wait.untilMain { model.phase == .accepted })
        #expect(await rig.repository.writes == ["respondBookingRequest:bk-1:true"])
    }

    @Test("A verified request has no badge and keeps its reason")
    func verifiedRequest() async {
        let (model, rig) = await makeModel()
        defer { rig.cleanUp() }
        #expect(model.unverifiedBadge == nil)
        #expect(model.showsReason)
    }
}
