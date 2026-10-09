//
//  HomeViewModelTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@Suite("HomeViewModel")
@MainActor
struct HomeViewModelTests {
    private let settings = CalendarSettings(profile: nil, fallbackTimeZoneID: "America/Sao_Paulo")

    private func makeModel(_ world: CalendarWorld, vault: VaultService? = nil) -> (HomeViewModel, AgendaDigestService) {
        let digest = AgendaDigestService(
            appointments: vault.map { AppointmentService(vault: $0) } ?? world.appointments,
            timeBlocks: world.timeBlocks, vault: vault ?? world.vault, now: { TestClock.now }
        )
        let model = HomeViewModel(
            settings: settings, digest: digest, bookingSetup: world.bookingSetup,
            prefs: FixedNotificationPrefsStore()
        )
        return (model, digest)
    }

    @Test("It is loading until the visits arrive, then shows the day's digest")
    func phases() async throws {
        let world = try await CalendarWorld.make()
        let next = makeVisit(clientID: world.ana.id, start: TestClock.date("2026-10-01 13:00"))
        try await world.appointments.book(next)
        let (model, digest) = makeModel(world)
        #expect(model.phase == .loading)

        model.start()
        let loaded = await Wait.untilMain { model.phase == .content && !digest.clients.isEmpty }

        #expect(loaded)
        let result = model.digest(now: TestClock.now)
        #expect(result.nextVisit?.id == next.id)
        #expect(result.nextVisit?.clientName == "Ana Costa")
        #expect(result.minutesUntilNext == 60)
        digest.stopListening()
    }

    @Test("The minutes until the next visit follow the clock the screen passes in")
    func clock() async throws {
        let world = try await CalendarWorld.make()
        try await world.appointments.book(makeVisit(clientID: world.ana.id, start: TestClock.date("2026-10-01 13:00")))
        let (model, digest) = makeModel(world)
        model.start()
        await Wait.untilMain { model.phase == .content }

        #expect(model.digest(now: TestClock.date("2026-10-01 12:00")).minutesUntilNext == 60)
        #expect(model.digest(now: TestClock.date("2026-10-01 12:45")).minutesUntilNext == 15)
        #expect(model.digest(now: TestClock.date("2026-10-01 13:10")).nextIsInProgress)
        digest.stopListening()
    }

    @Test("A vault that cannot be read is an error with a retry that works once it can")
    func unavailable() async throws {
        let world = try await CalendarWorld.make()
        let (model, digest) = makeModel(world, vault: VaultService(repository: nil))

        model.start()

        guard case .failed(let message) = model.phase else {
            Issue.record("expected a failure")
            return
        }
        #expect(!message.isEmpty)
        digest.stopListening()
    }

    @Test("Refreshing reads the services again")
    func refresh() async throws {
        let world = try await CalendarWorld.make()
        let (model, digest) = makeModel(world)
        model.start()
        await Wait.untilMain { model.phase == .content }
        try await world.repository.save(Service(name: "Peeling", durationMinutes: 45, position: 9))

        await model.refreshAsync()

        #expect(digest.services.contains { $0.name == "Peeling" })
        digest.stopListening()
    }
}
