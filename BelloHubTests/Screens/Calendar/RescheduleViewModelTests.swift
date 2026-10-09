//
//  RescheduleViewModelTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@Suite("RescheduleViewModel")
@MainActor
struct RescheduleViewModelTests {
    private func makeModel(
        _ world: CalendarWorld, id: UUID, appointments: AppointmentService? = nil
    ) -> RescheduleViewModel {
        RescheduleViewModel(
            appointmentID: id, timeZoneID: "America/Sao_Paulo", appointments: appointments ?? world.appointments,
            timeBlocks: world.timeBlocks, bookingSetup: world.bookingSetup, vault: world.vault,
            now: { TestClock.now }
        )
    }

    /// Ana's booked one-hour visit on Friday 15:00.
    private func bookVisit(_ world: CalendarWorld) async throws -> Appointment {
        let visit = makeVisit(clientID: world.ana.id, start: friday("15:00"), serviceName: "Glow Facial")
        try await world.appointments.book(visit)
        return visit
    }

    @Test("Loading reads the visit and the client and offers the next days that have room")
    func load() async throws {
        let world = try await CalendarWorld.make()
        let visit = try await bookVisit(world)
        let model = makeModel(world, id: visit.id)
        #expect(model.phase == .loading)
        await model.loadAsync()
        #expect(model.phase == .choosing)
        #expect(model.appointment?.id == visit.id && model.client?.name == "Ana Costa")
        #expect(model.offeredDays.count == RescheduleViewModel.offeredDayCount)
        // The sample week is Tuesday to Saturday: no Sunday and no Monday among the days offered.
        let weekdays = model.offeredDays.map { TestClock.calendar().component(.weekday, from: $0.day) }
        #expect(!weekdays.contains(1) && !weekdays.contains(2))
        #expect(model.day == model.offeredDays.first?.day)
        // Today (Thursday) is offered from now on; at 12:00 the lunch break pushes the first hour to 13:30.
        #expect(model.offeredDays.first?.day == TestClock.date("2026-10-01 00:00"))
        #expect(model.offeredDays.first?.slots.first == TestClock.date("2026-10-01 13:30"))
    }

    @Test("A visit that does not exist is not found")
    func notFound() async throws {
        let world = try await CalendarWorld.make()
        let model = makeModel(world, id: UUID())
        await model.loadAsync()
        #expect(model.phase == .notFound && model.errorMessage == nil)
    }

    @Test("An unreadable vault is an error with a retry, not a missing visit")
    func unreadable() async throws {
        let world = try await CalendarWorld.make()
        let model = RescheduleViewModel(
            appointmentID: UUID(), timeZoneID: "America/Sao_Paulo",
            appointments: AppointmentService(vault: VaultService(repository: nil)), timeBlocks: world.timeBlocks,
            bookingSetup: world.bookingSetup, vault: world.vault, now: { TestClock.now }
        )
        await model.loadAsync()
        #expect(model.phase == .notFound && model.errorMessage != nil)
    }

    @Test("The visit's own time is free for it, and the other visits' times are not")
    func slots() async throws {
        let world = try await CalendarWorld.make()
        let visit = try await bookVisit(world)
        let other = makeVisit(clientID: world.beatriz.id, start: friday("10:00"))
        try await world.appointments.book(other)
        let model = makeModel(world, id: visit.id)
        await model.loadAsync()
        model.selectDay(friday("00:00"))
        #expect(model.slots.contains(friday("15:00")))
        #expect(!model.slots.contains(friday("10:00")))
    }

    @Test("Moving the visit keeps its length, counts the move and puts it back to booked")
    func confirm() async throws {
        let world = try await CalendarWorld.make()
        var confirmed = makeVisit(clientID: world.ana.id, start: friday("15:00"), minutes: 90, status: .confirmed)
        confirmed.clientConfirmedAt = TestClock.now
        try await world.appointments.book(confirmed)
        let model = makeModel(world, id: confirmed.id)
        await model.loadAsync()
        #expect(!model.canConfirm)
        model.selectDay(TestClock.date("2026-10-03 00:00"))
        model.selectStart(TestClock.date("2026-10-03 11:00"))
        #expect(model.canConfirm && model.changesTime)
        #expect(await model.confirmAsync())
        guard case .moved(let moved) = model.phase else {
            Issue.record("expected the moved phase, got \(model.phase)")
            return
        }
        #expect(moved.startsAt == TestClock.date("2026-10-03 11:00"))
        #expect(moved.endsAt == TestClock.date("2026-10-03 12:30"))
        #expect(moved.rescheduleCount == 1 && moved.status == .booked && moved.clientConfirmedAt == nil)
        #expect(try await world.appointments.appointment(id: confirmed.id)?.startsAt == moved.startsAt)
    }

    @Test("A time that is not free warns and can still be chosen; the same time as now is not a change")
    func warnings() async throws {
        let world = try await CalendarWorld.make()
        let visit = try await bookVisit(world)
        let other = makeVisit(clientID: world.beatriz.id, start: friday("10:00"))
        try await world.appointments.book(other)
        let model = makeModel(world, id: visit.id)
        await model.loadAsync()
        model.selectDay(friday("00:00"))
        model.selectStart(friday("15:00"))
        #expect(!model.changesTime && model.warnings.isEmpty)
        model.selectStart(friday("10:30"))
        #expect(model.warnings.contains(.overlap(with: other.id)) && model.hasScheduleConflict)
        #expect(model.changesTime && model.canConfirm)
        model.selectStart(friday("12:15"))
        #expect(model.warnings.contains(.insideBreak(label: "Lunch")))
    }

    @Test("Choosing another day forgets the time, and a day outside the offered ones reads its own visits")
    func farDay() async throws {
        let world = try await CalendarWorld.make()
        let visit = try await bookVisit(world)
        let model = makeModel(world, id: visit.id)
        await model.loadAsync()
        let far = TestClock.date("2026-12-15 00:00")
        let blocker = makeVisit(clientID: world.beatriz.id, start: TestClock.date("2026-12-15 10:00"))
        try await world.appointments.book(blocker)
        model.selectStart(friday("15:00"))
        model.selectDay(far)
        #expect(model.start == nil)
        _ = await Wait.untilMain { model.context.appointments.contains { $0.id == blocker.id } }
        #expect(!model.slots.contains(TestClock.date("2026-12-15 10:00")))
    }

    @Test("A failed move changes nothing and says so")
    func failure() async throws {
        let world = try await CalendarWorld.make()
        let visit = try await bookVisit(world)
        let failing = FakeAgendaRepository(inner: world.memory)
        let model = makeModel(world, id: visit.id, appointments: AppointmentService(repository: failing))
        await model.loadAsync()
        await failing.setFailsWrites(true)
        model.selectDay(TestClock.date("2026-10-03 00:00"))
        model.selectStart(TestClock.date("2026-10-03 11:00"))
        #expect(await model.confirmAsync() == false)
        #expect(model.saveErrorMessage != nil && model.phase == .choosing)
        #expect(try await world.appointments.appointment(id: visit.id)?.startsAt == friday("15:00"))
    }
}
