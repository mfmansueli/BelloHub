//
//  RescheduleRequestViewModelTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@MainActor
@Suite("RescheduleRequestViewModel")
struct RescheduleRequestViewModelTests {
    private func makeModel() async -> (RescheduleRequestViewModel, InboxRig) {
        let booking = makeIncomingBooking(id: "bk-1", status: .confirmed, daysAhead: 1)
        let request = makeRescheduleRequest(bookingID: "bk-1", currentStart: booking.startsAt, hoursBefore: 19)
        let rig = InboxRig(repository: FakeInboxRepository(bookings: [booking], requests: [request]))
        await rig.start()
        return (RescheduleRequestViewModel(requestID: request.id, sync: rig.sync), rig)
    }

    @Test("Accepting moves the visit and the request ends accepted")
    func accept() async {
        let (model, rig) = await makeModel()
        defer { rig.cleanUp() }
        #expect(model.phase == .open)
        model.accept()
        #expect(await Wait.untilMain { model.phase == .accepted })
        #expect(await rig.repository.writes == ["respondRescheduleRequest:rr-1:true"])
    }

    @Test("When the asked time is taken first, it says so and only declining is left")
    func slotTaken() async {
        let (model, rig) = await makeModel()
        defer { rig.cleanUp() }
        await rig.repository.setRescheduleOutcome(.slotTaken)
        model.accept()
        #expect(await Wait.untilMain { model.phase == .slotTaken })
        model.accept()
        #expect(await rig.repository.writes.count == 1, "a taken time cannot be accepted again")
        model.decline()
        #expect(await Wait.untilMain { model.phase == .declined })
    }

    @Test("The timing reads her rules from the booking it moves")
    func timing() async {
        let (model, rig) = await makeModel()
        defer { rig.cleanUp() }
        #expect(model.timing?.freeWindowHours == 24 && model.timing?.isLate == true)
        #expect(model.booking?.id == "bk-1")
    }
}
