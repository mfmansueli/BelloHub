//
//  CalendarWriteThroughTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@MainActor
@Suite("CalendarIntegrationService write-through")
struct CalendarWriteThroughTests {
    private struct Rig {
        let world: CalendarWorld
        let writer: FakeCalendarEventWriter
        let service: CalendarIntegrationService
        let defaults: UserDefaults
        let suite: String
    }

    private func makeRig(access: CalendarAccessStatus = .full, enabled: Bool = true) async throws -> Rig {
        let world = try await CalendarWorld.make()
        let suite = "calendar-write-through-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite) ?? .standard
        defaults.set(enabled, forKey: DefaultsKey.appleCalendarEnabled)
        let writer = FakeCalendarEventWriter()
        let service = CalendarIntegrationService(
            provider: FakeCalendarAccess(current: access), writer: writer, appointments: world.appointments,
            vault: world.vault, defaults: defaults, now: { TestClock.now }
        )
        return Rig(world: world, writer: writer, service: service, defaults: defaults, suite: suite)
    }

    @Test("Connected with full access, her visits become events with no name by default")
    func mirrorsVisits() async throws {
        let rig = try await makeRig()
        defer { rig.defaults.removePersistentDomain(forName: rig.suite) }
        let visit = makeVisit(clientID: rig.world.ana.id, start: TestClock.date("2026-10-02 10:00"))
        try await rig.world.appointments.book(visit)

        await rig.service.sync()

        let event = try #require(rig.writer.events.first)
        #expect(rig.writer.events.count == 1)
        #expect(event.appointmentID == visit.id)
        #expect(event.start == visit.startsAt && event.end == visit.endsAt)
        #expect(!event.title.contains("Ana"), "names stay off the calendar while the lock screen hides them")
    }

    @Test("With names allowed on the lock screen the event says who and what")
    func namesWhenAllowed() async throws {
        let rig = try await makeRig()
        defer { rig.defaults.removePersistentDomain(forName: rig.suite) }
        rig.defaults.set(false, forKey: DefaultsKey.hideNamesOnLockScreen)
        try await rig.world.appointments.book(
            makeVisit(clientID: rig.world.ana.id, start: TestClock.date("2026-10-02 10:00"))
        )

        await rig.service.sync()

        #expect(rig.writer.events.first?.title == "Ana Costa · Glow Facial")
    }

    @Test("Nothing is written while switched off or without full access",
          arguments: [(CalendarAccessStatus.full, false), (.writeOnly, true), (.denied, true)])
    func needsSwitchAndFullAccess(access: CalendarAccessStatus, enabled: Bool) async throws {
        let rig = try await makeRig(access: access, enabled: enabled)
        defer { rig.defaults.removePersistentDomain(forName: rig.suite) }
        try await rig.world.appointments.book(
            makeVisit(clientID: rig.world.ana.id, start: TestClock.date("2026-10-02 10:00"))
        )

        await rig.service.sync()

        #expect(rig.writer.applied.isEmpty)
    }

    @Test("A cancelled visit leaves the calendar by itself, and switching off removes the calendar")
    func followsChangesThenRemoves() async throws {
        let rig = try await makeRig()
        defer { rig.defaults.removePersistentDomain(forName: rig.suite) }
        rig.service.startListening()
        defer { rig.service.stopListening() }
        let visit = makeVisit(clientID: rig.world.ana.id, start: TestClock.date("2026-10-02 10:00"))
        try await rig.world.appointments.book(visit)
        #expect(await Wait.untilMain { rig.writer.events.count == 1 })

        _ = try await rig.world.appointments.cancel(
            id: visit.id, by: .professional, policy: .standard, now: TestClock.now
        )
        #expect(await Wait.untilMain { rig.writer.events.isEmpty })

        rig.service.disconnect()
        #expect(await Wait.untilMain { rig.writer.removals == 1 })
        #expect(!rig.service.isEnabled)
    }

    @Test("Switching on asks once, then writes the visits already in the calendar")
    func connectWrites() async throws {
        let rig = try await makeRig(access: .notDetermined, enabled: false)
        defer { rig.defaults.removePersistentDomain(forName: rig.suite) }
        try await rig.world.appointments.book(
            makeVisit(clientID: rig.world.ana.id, start: TestClock.date("2026-10-02 10:00"))
        )

        let connected = await rig.service.connect()

        #expect(connected)
        #expect(rig.writer.events.count == 1)
    }

    @Test("A calendar that cannot be written leaves the vault as it is, and the next pass tries again")
    func failureIsRetried() async throws {
        let rig = try await makeRig()
        defer { rig.defaults.removePersistentDomain(forName: rig.suite) }
        try await rig.world.appointments.book(
            makeVisit(clientID: rig.world.ana.id, start: TestClock.date("2026-10-02 10:00"))
        )
        rig.writer.setFails(true)
        await rig.service.sync()
        #expect(rig.writer.events.isEmpty)

        rig.writer.setFails(false)
        await rig.service.sync()
        #expect(rig.writer.events.count == 1)
        #expect(try await rig.world.appointments.appointments(in: CalendarEventPlanner.window(now: TestClock.now))
            .count == 1)
    }
}
