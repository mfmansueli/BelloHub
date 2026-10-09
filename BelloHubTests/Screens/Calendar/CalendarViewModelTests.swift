//
//  CalendarViewModelTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@Suite("CalendarViewModel")
@MainActor
struct CalendarViewModelTests {
    private func makeModel(_ world: CalendarWorld, vault: VaultService? = nil) -> CalendarViewModel {
        CalendarViewModel(
            timeZoneID: "America/Sao_Paulo", firstWeekday: 2, appointments: world.appointments,
            timeBlocks: world.timeBlocks, bookingSetup: world.bookingSetup, vault: vault ?? world.vault,
            now: TestClock.now
        )
    }

    private func started(_ world: CalendarWorld) async -> CalendarViewModel {
        let model = makeModel(world)
        model.startListening()
        await Wait.untilMain { !model.isLoading }
        return model
    }

    @Test("It starts on today, in the business zone, in the day mode")
    func start() async throws {
        let world = try await CalendarWorld.make()
        let model = makeModel(world)
        #expect(model.selectedDay == TestClock.date("2026-10-01 00:00") && model.mode == .day)
        #expect(model.isLoading)
        #expect(model.weekDays.count == 7 && model.weekDays.first == TestClock.date("2026-09-28 00:00"))
    }

    @Test("Listening delivers the week's visits and blocks, and the client names")
    func listening() async throws {
        let world = try await CalendarWorld.make()
        let visit = makeVisit(clientID: world.ana.id, start: TestClock.date("2026-10-01 15:00"))
        try await world.appointments.book(visit)
        try await world.timeBlocks.block([makeBlock(start: friday("14:00"))])
        let model = await started(world)
        await Wait.untilMain { model.blocks.count == 1 && !model.clients.isEmpty }
        #expect(model.appointments.map(\.id) == [visit.id])
        #expect(model.visits(on: TestClock.date("2026-10-01 00:00")).map(\.id) == [visit.id])
        #expect(model.clientName(of: visit) == "Ana Costa")
        let bands = model.layout(for: friday("00:00")).bands
        #expect(bands.contains { if case .blocked = $0.kind { true } else { false } })
        model.stopListening()
    }

    @Test("A change in the vault reaches the calendar without reloading")
    func live() async throws {
        let world = try await CalendarWorld.make()
        let model = await started(world)
        #expect(model.appointments.isEmpty)
        let visit = makeVisit(clientID: world.ana.id, start: TestClock.date("2026-10-01 15:00"))
        try await world.appointments.book(visit)
        #expect(await Wait.untilMain { model.appointments.count == 1 })
        _ = try await world.appointments.cancel(id: visit.id, by: .professional, policy: .standard, now: TestClock.now)
        #expect(await Wait.untilMain { model.visits(on: model.selectedDay).isEmpty })
        model.stopListening()
    }

    @Test("Stepping moves a day in the day mode and a week in the week mode, and reads the new week")
    func stepping() async throws {
        let world = try await CalendarWorld.make()
        let model = await started(world)
        model.step(forward: true)
        #expect(model.selectedDay == friday("00:00"))
        model.step(forward: false)
        model.step(forward: false)
        #expect(model.selectedDay == TestClock.date("2026-09-30 00:00"))
        model.mode = .week
        model.step(forward: true)
        #expect(model.selectedDay == TestClock.date("2026-10-07 00:00"))
        let nextWeek = makeVisit(clientID: world.ana.id, start: TestClock.date("2026-10-08 10:00"))
        try await world.appointments.book(nextWeek)
        #expect(await Wait.untilMain { model.appointments.map(\.id) == [nextWeek.id] })
        model.goToToday(now: TestClock.now)
        #expect(model.selectedDay == TestClock.date("2026-10-01 00:00"))
        model.stopListening()
    }

    @Test("Selecting a day inside the week does not restart the reading; another week does")
    func selecting() async throws {
        let world = try await CalendarWorld.make()
        let model = await started(world)
        model.select(day: TestClock.date("2026-10-03 18:00"))
        #expect(model.selectedDay == TestClock.date("2026-10-03 00:00"))
        #expect(!model.isLoading)
        model.select(day: TestClock.date("2026-10-12 09:00"))
        #expect(model.selectedDay == TestClock.date("2026-10-12 00:00"))
        model.stopListening()
    }

    @Test("A cancelled visit leaves the calendar and a no-show stays")
    func cancelledHidden() async throws {
        let world = try await CalendarWorld.make()
        let day = TestClock.date("2026-10-01 00:00")
        try await world.appointments.book(makeVisit(start: TestClock.date("2026-10-01 10:00"), status: .cancelled))
        let missed = makeVisit(start: TestClock.date("2026-10-01 11:00"), status: .noShow)
        try await world.appointments.book(missed)
        let model = await started(world)
        #expect(model.visits(on: day).map(\.id) == [missed.id])
    }

    @Test("The visible hours are the same for every day of the week, so the week grid lines up")
    func sharedScale() async throws {
        let world = try await CalendarWorld.make()
        try await world.appointments.book(makeVisit(start: TestClock.date("2026-10-01 07:30")))
        let model = await started(world)
        let thursday = model.layout(for: TestClock.date("2026-10-01 00:00"))
        let saturday = model.layout(for: TestClock.date("2026-10-03 00:00"))
        #expect(thursday.window.duration == saturday.window.duration)
        #expect(thursday.hourMarks.count == saturday.hourMarks.count)
        model.stopListening()
    }

    @Test("Stopping forgets everything that was read")
    func stopping() async throws {
        let world = try await CalendarWorld.make()
        try await world.appointments.book(makeVisit(clientID: world.ana.id, start: TestClock.date("2026-10-01 15:00")))
        let model = await started(world)
        await Wait.untilMain { !model.clients.isEmpty }
        model.stopListening()
        #expect(model.appointments.isEmpty && model.blocks.isEmpty && model.clients.isEmpty && model.isLoading)
        model.startListening()
        #expect(await Wait.untilMain { !model.isLoading && model.appointments.count == 1 })
        model.stopListening()
    }

    @Test("A vault that cannot be opened says so instead of loading forever")
    func unavailable() async throws {
        let world = try await CalendarWorld.make()
        let model = makeModel(world, vault: VaultService(repository: nil))
        model.startListening()
        #expect(model.errorMessage != nil && !model.isLoading)
    }
}
