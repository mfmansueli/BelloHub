//
//  AgendaDigestServiceTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@Suite("AgendaDigestService")
@MainActor
struct AgendaDigestServiceTests {
    private func makeService(_ world: CalendarWorld, vault: VaultService? = nil) -> AgendaDigestService {
        AgendaDigestService(
            appointments: vault.map { AppointmentService(vault: $0) } ?? world.appointments,
            timeBlocks: world.timeBlocks, vault: vault ?? world.vault, now: { TestClock.now }
        )
    }

    @Test("Listening delivers every visit, the clients, the services and the blocks of the coming days")
    func listening() async throws {
        let world = try await CalendarWorld.make()
        let old = makeVisit(clientID: world.ana.id, start: TestClock.days(-400), status: .completed)
        let next = makeVisit(clientID: world.ana.id, start: TestClock.date("2026-10-02 10:00"))
        try await world.appointments.book(old)
        try await world.appointments.book(next)
        try await world.timeBlocks.block([makeBlock(start: friday("14:00"))])
        let service = makeService(world)
        #expect(service.isLoading)

        service.startListening()
        let arrived = await Wait.untilMain {
            !service.isLoading && service.blocks.count == 1 && service.clients.count == 2 && !service.services.isEmpty
        }

        #expect(arrived)
        #expect(Set(service.appointments.map(\.id)) == [old.id, next.id])
        #expect(service.errorMessage == nil)
        service.stopListening()
    }

    @Test("A change in the calendar reaches the service")
    func changes() async throws {
        let world = try await CalendarWorld.make()
        let service = makeService(world)
        service.startListening()
        await Wait.untilMain { !service.isLoading }
        let visit = makeVisit(clientID: world.ana.id, start: TestClock.date("2026-10-02 10:00"))

        try await world.appointments.book(visit)

        #expect(await Wait.untilMain { service.appointments.map(\.id) == [visit.id] })
        service.stopListening()
    }

    @Test("Stopping forgets everything, and listening again starts from the vault")
    func stopForgets() async throws {
        let world = try await CalendarWorld.make()
        try await world.appointments.book(makeVisit(clientID: world.ana.id, start: TestClock.date("2026-10-02 10:00")))
        let service = makeService(world)
        service.startListening()
        await Wait.untilMain { !service.appointments.isEmpty }

        service.stopListening()

        #expect(service.appointments.isEmpty && service.clients.isEmpty && service.isLoading)
        service.startListening()
        #expect(await Wait.untilMain { !service.appointments.isEmpty })
        service.stopListening()
    }

    @Test("Listening twice does not start a second observation")
    func idempotent() async throws {
        let world = try await CalendarWorld.make()
        let service = makeService(world)

        service.startListening()
        service.startListening()

        #expect(await Wait.untilMain { !service.isLoading })
        service.stopListening()
    }

    @Test("A vault that cannot be read is an error, not an endless spinner")
    func unavailable() async throws {
        let world = try await CalendarWorld.make()
        let service = makeService(world, vault: VaultService(repository: nil))

        service.startListening()

        #expect(service.errorMessage != nil)
        #expect(!service.isLoading)
    }

    @Test("Refreshing restarts the observation when it had stopped")
    func refreshRestarts() async throws {
        let world = try await CalendarWorld.make()
        try await world.appointments.book(makeVisit(clientID: world.ana.id, start: TestClock.date("2026-10-02 10:00")))
        let service = makeService(world)

        await service.refresh()

        #expect(await Wait.untilMain { !service.appointments.isEmpty })
        service.stopListening()
    }
}
