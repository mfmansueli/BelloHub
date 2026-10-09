//
//  WeekGlanceViewModelTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@Suite("WeekGlanceViewModel")
@MainActor
struct WeekGlanceViewModelTests {
    private func makeModel(_ world: CalendarWorld, appointments: AppointmentService? = nil) -> WeekGlanceViewModel {
        WeekGlanceViewModel(
            timeZoneID: "America/Sao_Paulo", firstWeekday: 2, appointments: appointments ?? world.appointments,
            timeBlocks: world.timeBlocks, bookingSetup: world.bookingSetup, vault: world.vault,
            now: { TestClock.now }
        )
    }

    @Test("The week of today is summarized from the vault")
    func summary() async throws {
        let world = try await CalendarWorld.make()
        try await world.appointments.book(makeVisit(clientID: world.ana.id, start: TestClock.date("2026-10-01 15:00")))
        try await world.appointments.book(makeVisit(clientID: world.beatriz.id, start: friday("10:00")))
        let model = makeModel(world)
        #expect(!model.hasLoaded)
        await model.loadAsync()
        let summary = try #require(model.summary)
        #expect(summary.leftToday == 1)
        #expect(summary.rows.map(\.booked).reduce(0, +) == 2)
        #expect(summary.openSlotCount > 0)
        #expect(model.weekInterval.start == TestClock.date("2026-09-28 00:00"))
        #expect(model.errorMessage == nil)
    }

    @Test("Clients who have not been back come from the follow-up rules")
    func notReturned() async throws {
        let world = try await CalendarWorld.make()
        try await world.appointments.book(makeVisit(
            clientID: world.ana.id, start: TestClock.days(-90), status: .completed
        ))
        try await world.appointments.book(makeVisit(
            clientID: world.beatriz.id, start: TestClock.days(-10), status: .completed
        ))
        let model = makeModel(world)
        await model.loadAsync()
        #expect(model.notReturnedCount == 1)
    }

    @Test("The shortest active service sets the size of an open slot")
    func shortestService() async throws {
        let world = try await CalendarWorld.make()
        let quick = Service(name: "Brow shaping", durationMinutes: 15, position: 5)
        try await world.repository.save(quick)
        let model = makeModel(world)
        await model.loadAsync()
        let withQuick = try #require(model.summary).openSlotCount
        var off = quick
        off.isActive = false
        try await world.repository.save(off)
        await model.loadAsync()
        #expect(try #require(model.summary).openSlotCount < withQuick)
    }

    @Test("A vault that cannot be read is an error with a retry, and a retry works")
    func unreadable() async throws {
        let world = try await CalendarWorld.make()
        let model = makeModel(world, appointments: AppointmentService(vault: VaultService(repository: nil)))
        await model.loadAsync()
        #expect(model.errorMessage != nil && model.summary == nil && !model.isLoading)
        let healthy = makeModel(world)
        await healthy.loadAsync()
        #expect(healthy.summary != nil)
    }
}
