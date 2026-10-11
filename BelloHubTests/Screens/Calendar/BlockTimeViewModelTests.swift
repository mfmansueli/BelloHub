//
//  BlockTimeViewModelTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@Suite("BlockTimeViewModel")
@MainActor
struct BlockTimeViewModelTests {
    private func makeModel(
        _ world: CalendarWorld, day: Date? = friday("00:00"), appointments: AppointmentService? = nil
    ) -> BlockTimeViewModel {
        BlockTimeViewModel(
            day: day, timeZoneID: "America/Sao_Paulo", appointments: appointments ?? world.appointments,
            timeBlocks: world.timeBlocks, bookingSetup: world.bookingSetup, vault: world.vault,
            now: { TestClock.now }
        )
    }

    private func range(_ world: CalendarWorld) -> DateInterval {
        DateInterval(start: TestClock.date("2026-10-01 00:00"), end: TestClock.date("2026-10-20 00:00"))
    }

    @Test("The sheet offers fourteen days from the one it was opened on, with that day chosen")
    func days() async throws {
        let world = try await CalendarWorld.make()
        let model = makeModel(world)
        #expect(model.candidateDays.count == BlockTimeViewModel.candidateDayCount)
        #expect(model.candidateDays.first == TestClock.date("2026-10-02 00:00"))
        #expect(model.selectedDays == [TestClock.date("2026-10-02 00:00")])
        // Opened with no day, it starts today.
        #expect(makeModel(world, day: nil).candidateDays.first == TestClock.date("2026-10-01 00:00"))
    }

    @Test("Days can be added and removed, but the last chosen day stays")
    func toggling() async throws {
        let world = try await CalendarWorld.make()
        let model = makeModel(world)
        let saturday = TestClock.date("2026-10-03 00:00")
        model.toggleDay(saturday)
        #expect(model.selectedDays.count == 2)
        model.toggleDay(saturday)
        model.toggleDay(TestClock.date("2026-10-02 00:00"))
        #expect(model.selectedDays == [TestClock.date("2026-10-02 00:00")])
    }

    @Test("Each day counts the booked visits inside the closed time, and the button says how many it would cancel")
    func counts() async throws {
        let world = try await CalendarWorld.make()
        try await world.appointments.book(makeVisit(clientID: world.ana.id, start: friday("10:00")))
        try await world.appointments.book(makeVisit(clientID: world.beatriz.id, start: friday("15:00")))
        try await world.appointments.book(makeVisit(clientID: world.ana.id, start: TestClock.date("2026-10-03 10:00")))
        let model = makeModel(world)
        await model.loadAsync()
        let saturday = TestClock.date("2026-10-03 00:00")
        #expect(model.bookedCounts[friday("00:00")] == 2 && model.bookedCounts[saturday] == 1)
        #expect(model.affectedVisits.count == 2 && model.cancelsVisits)
        model.toggleDay(saturday)
        #expect(model.affectedVisits.count == 3)
        model.scope = .someHours
        model.setStart(minutes: 14 * 60)
        model.setEnd(minutes: 16 * 60)
        #expect(model.affectedVisits.count == 1)
        model.visitChoice = .keep
        #expect(!model.cancelsVisits)
    }

    @Test("Hours that end before they start cannot be saved, and a later start pushes the end")
    func hours() async throws {
        let world = try await CalendarWorld.make()
        let model = makeModel(world)
        await model.loadAsync()
        model.scope = .someHours
        model.setEnd(minutes: 9 * 60)
        #expect(model.issue == .emptyHours && !model.canSave)
        model.setStart(minutes: 8 * 60)
        #expect(model.issue == nil && model.canSave)
        model.setStart(minutes: 17 * 60 + 30)
        #expect(model.endMinutes == 18 * 60 + 30)
    }

    @Test("Saving closes the days, stores the private reason and cancels the visits as the professional")
    func cancelAndInvite() async throws {
        let world = try await CalendarWorld.make()
        let first = makeVisit(clientID: world.ana.id, start: friday("10:00"))
        let second = makeVisit(clientID: world.beatriz.id, start: friday("15:00"))
        try await world.appointments.book(first)
        try await world.appointments.book(second)
        let model = makeModel(world)
        await model.loadAsync()
        model.reason = .notWell
        #expect(await model.saveAsync(reasonText: "Not feeling well"))
        guard case .done(let outcome) = model.phase else {
            Issue.record("expected the done phase")
            return
        }
        #expect(outcome.blockedDays == 1 && outcome.cancelled.count == 2 && outcome.failedCancellations == 0)
        let blocks = try await world.timeBlocks.blocks(in: range(world))
        #expect(blocks.count == 1 && blocks.first?.reason == "Not feeling well")
        #expect(blocks.first?.startsAt == friday("00:00"))
        for visit in [first, second] {
            let stored = try #require(try await world.appointments.appointment(id: visit.id))
            #expect(stored.status == .cancelled && stored.cancelledBy == .professional)
            #expect(!stored.isLateCancellation, "a cancellation by the professional is never late (D13)")
        }
    }

    @Test("Keeping the visits leaves them booked inside the blocked time")
    func keep() async throws {
        let world = try await CalendarWorld.make()
        let visit = makeVisit(clientID: world.ana.id, start: friday("10:00"))
        try await world.appointments.book(visit)
        let model = makeModel(world)
        await model.loadAsync()
        model.visitChoice = .keep
        #expect(await model.saveAsync(reasonText: nil))
        guard case .done(let outcome) = model.phase else {
            Issue.record("expected the done phase")
            return
        }
        #expect(outcome.cancelled.isEmpty && outcome.kept.map(\.id) == [visit.id])
        #expect(try await world.appointments.appointment(id: visit.id)?.status == .booked)
        #expect(try await world.timeBlocks.blocks(in: range(world)).count == 1)
    }

    @Test("A cancellation that fails is counted, and the visit is listed as kept; the block stays saved")
    func partialFailure() async throws {
        let world = try await CalendarWorld.make()
        let stubborn = makeVisit(clientID: world.ana.id, start: friday("10:00"))
        let fine = makeVisit(clientID: world.beatriz.id, start: friday("15:00"))
        try await world.appointments.book(stubborn)
        try await world.appointments.book(fine)
        let flaky = FakeAgendaRepository(inner: world.memory)
        await flaky.failWrites(ofAppointment: stubborn.id)
        let model = makeModel(world, appointments: AppointmentService(repository: flaky))
        await model.loadAsync()
        #expect(await model.saveAsync(reasonText: nil))
        guard case .done(let outcome) = model.phase else {
            Issue.record("expected the done phase")
            return
        }
        #expect(outcome.failedCancellations == 1)
        #expect(outcome.cancelled.map(\.id) == [fine.id] && outcome.kept.map(\.id) == [stubborn.id])
        #expect(try await world.timeBlocks.blocks(in: range(world)).count == 1)
    }

    @Test("When the block itself cannot be stored nothing is cancelled and the sheet says so")
    func blockFails() async throws {
        let world = try await CalendarWorld.make()
        let visit = makeVisit(clientID: world.ana.id, start: friday("10:00"))
        try await world.appointments.book(visit)
        let model = BlockTimeViewModel(
            day: friday("00:00"), timeZoneID: "America/Sao_Paulo", appointments: world.appointments,
            timeBlocks: TimeBlockService(vault: VaultService(repository: nil)), bookingSetup: world.bookingSetup,
            vault: world.vault, now: { TestClock.now }
        )
        await model.loadAsync()
        #expect(await model.saveAsync(reasonText: nil) == false)
        #expect(model.saveErrorMessage != nil && model.phase == .editing)
        #expect(try await world.appointments.appointment(id: visit.id)?.status == .booked)
    }

    @Test("Several days are blocked together, one block each")
    func severalDays() async throws {
        let world = try await CalendarWorld.make()
        let model = makeModel(world)
        await model.loadAsync()
        model.toggleDay(TestClock.date("2026-10-03 00:00"))
        model.toggleDay(TestClock.date("2026-10-06 00:00"))
        #expect(await model.saveAsync(reasonText: "Holiday"))
        let blocks = try await world.timeBlocks.blocks(in: range(world))
        let expected = [friday("00:00"), TestClock.date("2026-10-03 00:00"), TestClock.date("2026-10-06 00:00")]
        #expect(blocks.map(\.startsAt) == expected)
    }

    @Test("An unreadable calendar says so and cannot be saved")
    func unreadable() async throws {
        let world = try await CalendarWorld.make()
        let model = BlockTimeViewModel(
            day: friday("00:00"), timeZoneID: "America/Sao_Paulo",
            appointments: AppointmentService(vault: VaultService(repository: nil)), timeBlocks: world.timeBlocks,
            bookingSetup: world.bookingSetup, vault: world.vault, now: { TestClock.now }
        )
        await model.loadAsync()
        #expect(model.errorMessage != nil && !model.canSave)
    }

    // MARK: - Business time zone (fix-reschedule-day)

    @Test("Closing a day closes that day in the calendar's zone, whatever zone her hours were saved in",
          arguments: ZoneMismatch.all)
    func businessZone(_ zones: ZoneMismatch) async throws {
        let world = try await CalendarWorld.make(availability: zones.availability)
        try await world.appointments.book(makeVisit(clientID: world.ana.id, start: zones.at("10:00")))
        let model = BlockTimeViewModel(
            day: zones.day, timeZoneID: zones.business, appointments: world.appointments,
            timeBlocks: world.timeBlocks, bookingSetup: world.bookingSetup, vault: world.vault,
            now: { TestClock.now }
        )
        await model.loadAsync()
        #expect(model.bookedCounts[zones.day] == 1, "the day's own visit is inside the closed day")
        #expect(model.affectedVisits.count == 1)
        #expect(await model.saveAsync(reasonText: nil))
        let blocks = try await world.timeBlocks.blocks(in: zones.days.interval(of: zones.day))
        #expect(blocks.map(\.interval) == [zones.days.interval(of: zones.day)])
    }
}
