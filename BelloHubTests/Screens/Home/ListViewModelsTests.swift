//
//  ListViewModelsTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

/// The ViewModels of the follow-up queue and Alerts, with fakes for the phone's permission, settings and chats.
@Suite("Follow-up queue and Alerts view models")
@MainActor
struct ListViewModelsTests {
    private let settings = CalendarSettings(profile: nil, fallbackTimeZoneID: "America/Sao_Paulo")

    private final class SettingsSpy: SettingsOpening {
        private(set) var opened = 0
        func openSettings() { opened += 1 }
    }

    /// Ana was last here 90 days ago, for a service that asks for a return after four weeks.
    private func makeWorld() async throws -> (CalendarWorld, AgendaDigestService) {
        let world = try await CalendarWorld.make()
        var old = makeVisit(clientID: world.ana.id, start: TestClock.days(-90), status: .completed)
        old.serviceID = world.glow.id
        try await world.appointments.book(old)
        let digest = AgendaDigestService(
            appointments: world.appointments, timeBlocks: world.timeBlocks, vault: world.vault, now: { TestClock.now }
        )
        digest.startListening()
        await Wait.untilMain { !digest.isLoading && digest.clients.count == 2 && !digest.services.isEmpty }
        return (world, digest)
    }

    // MARK: - Follow-up queue

    private func makeQueue(_ world: CalendarWorld) -> (FollowUpQueueService, String) {
        let suite = "queue-vm-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite) ?? .standard
        let queue = FollowUpQueueService(defaults: defaults, vault: world.vault, now: { TestClock.now })
        queue.start(userID: "user-1")
        return (queue, suite)
    }

    private func makeFollowUps(
        _ world: CalendarWorld, digest: AgendaDigestService, queue: FollowUpQueueService, filter: FollowUpFilter = .all
    ) -> FollowUpsViewModel {
        FollowUpsViewModel(
            settings: settings, digest: digest, bookingSetup: world.bookingSetup, queue: queue,
            appointments: world.appointments, filter: filter, prefs: FixedNotificationPrefsStore(),
            now: { TestClock.now }
        )
    }

    @Test("The queue keeps a client's return and win back on one row, the return first")
    func queueGroups() async throws {
        let (world, digest) = try await makeWorld()
        let (queue, suite) = makeQueue(world)
        defer { UserDefaults.standard.removePersistentDomain(forName: suite) }
        let model = makeFollowUps(world, digest: digest, queue: queue)
        let row = try #require(model.queue(now: TestClock.now).rows.first)

        #expect(row.client.id == world.ana.id)
        #expect(row.items.map(\.kind) == [.returnDue, .notBack])
        #expect(model.phase(now: TestClock.now) == .content)
        #expect(FollowUpAction.primary(for: row.primary)
                == .sheet(.clientMessage(ClientMessageRequest(clientID: world.ana.id,
                                                              kind: .followUp(serviceName: "Glow Facial")))))
        digest.stopListening()
    }

    @Test("Later, dismiss and her own mark of sending set a suggestion aside; bringing it back restores it")
    func queueDecisions() async throws {
        let (world, digest) = try await makeWorld()
        let (queue, suite) = makeQueue(world)
        defer { UserDefaults.standard.removePersistentDomain(forName: suite) }
        let model = makeFollowUps(world, digest: digest, queue: queue)
        let row = try #require(model.queue(now: TestClock.now).rows.first)
        let returnDue = row.items[0]
        let notBack = row.items[1]

        model.snooze(returnDue)
        model.markSent(notBack)
        let after = model.queue(now: TestClock.now)

        #expect(after.rows.isEmpty)
        #expect(after.setAside.first?.items.map(\.kind) == [.returnDue, .notBack])
        #expect(after.setAside.first?.items[1].delivery == .markedSentByHer(at: TestClock.now))

        model.restore(returnDue)
        #expect(model.queue(now: TestClock.now).rows.first?.items.map(\.kind) == [.returnDue])
        digest.stopListening()
    }

    @Test("A chat opened from the queue shows as opened, never as sent")
    func queueOpened() async throws {
        let (world, digest) = try await makeWorld()
        let (queue, suite) = makeQueue(world)
        defer { UserDefaults.standard.removePersistentDomain(forName: suite) }
        let messages = MessageService(vault: world.vault, sender: FakeMessageSender())
        let model = makeFollowUps(world, digest: digest, queue: queue, filter: .notBack)

        await messages.send(
            text: "Hi", to: world.ana.id, phoneE164: "+5511981234410", template: "winBack", now: TestClock.now
        )
        await queue.refreshLogs()

        let item = try #require(model.queue(now: TestClock.now).rows(.notBack).first?.primary)
        #expect(item.delivery == .conversationOpened(at: TestClock.now))
        #expect(FollowUpAction.offersMarkSent(item))
        digest.stopListening()
    }

    // MARK: - Alerts

    private func makeAlerts(
        _ world: CalendarWorld, digest: AgendaDigestService, status: PermissionStatus, spy: SettingsSpy = SettingsSpy(),
        scheduler: FakeNotificationScheduler = FakeNotificationScheduler()
    ) async -> AlertsViewModel {
        let permissions = PermissionService(provider: FakePermissionStatusProvider(status: status))
        let notifications = NotificationService(
            appointments: world.appointments, vault: world.vault, permissions: permissions, profile: world.profile,
            prefs: FixedNotificationPrefsStore(), scheduler: scheduler, now: { TestClock.now }
        )
        return AlertsViewModel(
            settings: settings, digest: digest, bookingSetup: world.bookingSetup, permissions: permissions,
            notifications: notifications, settingsOpener: spy, prefs: FixedNotificationPrefsStore()
        )
    }

    @Test("Without the queue, Alerts has nothing local to say about a client away for months")
    func alertsList() async throws {
        let (world, digest) = try await makeWorld()
        let model = await makeAlerts(world, digest: digest, status: .granted)
        #expect(model.list(now: TestClock.now).isEmpty)
        #expect(model.phase(now: TestClock.now) == .empty)
        digest.stopListening()
    }

    @Test("The permission strip follows the system's answer",
          arguments: [(PermissionStatus.granted, AlertsViewModel.PermissionNotice.none),
                      (.notDetermined, .ask), (.denied, .denied)])
    func notice(status: PermissionStatus, expected: AlertsViewModel.PermissionNotice) async throws {
        let (world, digest) = try await makeWorld()
        let model = await makeAlerts(world, digest: digest, status: status)
        #expect(model.notice == .ask)

        model.start()

        #expect(await Wait.untilMain { model.notice == expected })
        digest.stopListening()
    }

    @Test("Turning notifications on asks the system and schedules at once when she agrees")
    func turnOn() async throws {
        let (world, digest) = try await makeWorld()
        try await world.appointments.book(makeVisit(clientID: world.ana.id, start: TestClock.date("2026-10-02 10:00")))
        let scheduler = FakeNotificationScheduler()
        let model = await makeAlerts(world, digest: digest, status: .granted, scheduler: scheduler)

        await model.turnOnNotificationsAsync()

        #expect(model.notice == .none)
        #expect(scheduler.scheduled.contains { $0.kind == .nextVisit })
        digest.stopListening()
    }

    @Test("Refusing the system dialog schedules nothing")
    func turnOnRefused() async throws {
        let (world, digest) = try await makeWorld()
        let scheduler = FakeNotificationScheduler()
        let model = await makeAlerts(world, digest: digest, status: .denied, scheduler: scheduler)

        await model.turnOnNotificationsAsync()

        #expect(model.notice == .denied)
        #expect(scheduler.plans.isEmpty)
        digest.stopListening()
    }

    @Test("After a refusal Settings is the way back")
    func settingsOpens() async throws {
        let (world, digest) = try await makeWorld()
        let spy = SettingsSpy()
        let model = await makeAlerts(world, digest: digest, status: .denied, spy: spy)

        model.openSettings()

        #expect(spy.opened == 1)
        digest.stopListening()
    }
}
