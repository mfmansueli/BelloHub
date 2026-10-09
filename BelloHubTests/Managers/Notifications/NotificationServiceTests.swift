//
//  NotificationServiceTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@Suite("NotificationService")
@MainActor
struct NotificationServiceTests {
    private func makeService(
        _ world: CalendarWorld, scheduler: FakeNotificationScheduler, status: PermissionStatus = .granted,
        prefs: NotificationPrefs = .standard
    ) async -> NotificationService {
        let permissions = PermissionService(provider: FakePermissionStatusProvider(status: status))
        await permissions.refresh()
        return NotificationService(
            appointments: world.appointments, vault: world.vault, permissions: permissions, profile: world.profile,
            prefs: FixedNotificationPrefsStore(prefs), scheduler: scheduler, now: { TestClock.now }
        )
    }

    @Test("A booked visit schedules the next-visit reminder and the reminders-ready notification")
    func schedulesFromTheCalendar() async throws {
        let world = try await CalendarWorld.make()
        let visit = makeVisit(clientID: world.ana.id, start: TestClock.date("2026-10-02 10:00"))
        try await world.appointments.book(visit)
        let scheduler = FakeNotificationScheduler()
        let service = await makeService(world, scheduler: scheduler)

        await service.reschedule()

        let kinds = scheduler.scheduled.map(\.kind)
        #expect(kinds.contains(.nextVisit))
        #expect(kinds.contains(.remindersReady))
        #expect(service.scheduledCount == scheduler.scheduled.count)
        #expect(scheduler.scheduled.first { $0.kind == .nextVisit }?.fireDate == TestClock.date("2026-10-02 09:45"))
    }

    @Test("Nothing is scheduled without the notification permission, and what was scheduled is removed",
          arguments: [PermissionStatus.denied, .notDetermined])
    func needsPermission(status: PermissionStatus) async throws {
        let world = try await CalendarWorld.make()
        try await world.appointments.book(makeVisit(clientID: world.ana.id, start: TestClock.date("2026-10-02 10:00")))
        let scheduler = FakeNotificationScheduler()
        let service = await makeService(world, scheduler: scheduler, status: status)

        await service.reschedule()

        #expect(scheduler.scheduled.isEmpty)
        #expect(scheduler.removeAllCount == 1)
        #expect(service.scheduledCount == 0)
    }

    @Test("Her choices are read from the prefs store: a switched-off kind is not scheduled")
    func readsPrefs() async throws {
        let world = try await CalendarWorld.make()
        try await world.appointments.book(makeVisit(clientID: world.ana.id, start: TestClock.date("2026-10-02 10:00")))
        var prefs = NotificationPrefs.standard
        prefs.clientRemindersEnabled = false
        let scheduler = FakeNotificationScheduler()
        let service = await makeService(world, scheduler: scheduler, prefs: prefs)

        await service.reschedule()

        #expect(!scheduler.scheduled.map(\.kind).contains(.remindersReady))
        #expect(scheduler.scheduled.map(\.kind).contains(.nextVisit))
    }

    @Test("A change in the calendar reschedules by itself, and a cancelled visit leaves the plan")
    func reschedulesAfterCalendarChanges() async throws {
        let world = try await CalendarWorld.make()
        let scheduler = FakeNotificationScheduler()
        let service = await makeService(world, scheduler: scheduler)
        service.startListening()
        defer { service.stopListening() }

        let visit = makeVisit(clientID: world.ana.id, start: TestClock.date("2026-10-02 10:00"))
        try await world.appointments.book(visit)
        let planned = await Wait.until { scheduler.scheduled.contains { $0.id.contains(visit.id.uuidString) } }
        #expect(planned)

        _ = try await world.appointments.cancel(id: visit.id, by: .professional, policy: .standard, now: TestClock.now)
        let removed = await Wait.until { !scheduler.scheduled.contains { $0.id.contains(visit.id.uuidString) } }
        #expect(removed)
    }

    @Test("Removing everything stops the observation and clears the phone")
    func removeAll() async throws {
        let world = try await CalendarWorld.make()
        try await world.appointments.book(makeVisit(clientID: world.ana.id, start: TestClock.date("2026-10-02 10:00")))
        let scheduler = FakeNotificationScheduler()
        let service = await makeService(world, scheduler: scheduler)
        await service.reschedule()
        #expect(!scheduler.scheduled.isEmpty)

        await service.removeAll()

        #expect(scheduler.scheduled.isEmpty)
        #expect(service.scheduledCount == 0)
    }

    @Test("A vault that cannot be read keeps what is scheduled")
    func unreadableVault() async {
        let vault = VaultService(repository: nil)
        let permissions = PermissionService(provider: FakePermissionStatusProvider(status: .granted))
        await permissions.refresh()
        let scheduler = FakeNotificationScheduler()
        let service = NotificationService(
            appointments: AppointmentService(vault: vault), vault: vault, permissions: permissions,
            profile: ProfileService(vault: vault), prefs: FixedNotificationPrefsStore(), scheduler: scheduler,
            now: { TestClock.now }
        )

        await service.reschedule()
        service.startListening()

        // Without a vault there is nothing to read; the old plan stays and nothing crashes.
        #expect(scheduler.plans.isEmpty)
        #expect(scheduler.removeAllCount == 0)
    }
}
