//
//  ListViewModelsTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

/// The ViewModels of Follow-ups, Win back and Alerts, with fakes for the phone's permission, settings and chats.
@Suite("Follow-ups, Win back and Alerts view models")
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

    // MARK: - Follow-ups

    @Test("Follow-ups builds its list and tells which clients she already wrote to")
    func followUps() async throws {
        let (world, digest) = try await makeWorld()
        let messages = MessageService(vault: world.vault, sender: FakeMessageSender())
        let model = FollowUpsViewModel(
            settings: settings, digest: digest, bookingSetup: world.bookingSetup, messages: messages,
            prefs: FixedNotificationPrefsStore()
        )
        let list = model.list(now: TestClock.now)
        let row = try #require(list.due.first)

        #expect(list.due.map(\.client.id) == [world.ana.id])
        #expect(model.phase(now: TestClock.now) == .content)
        #expect(model.message(for: row) == ClientMessageRequest(clientID: world.ana.id, kind: .followUp(serviceName: "Glow Facial")))
        #expect(!model.wasOpened(world.ana.id))

        await messages.send(text: "Hi", to: world.ana.id, phoneE164: "+5511981234410", template: "followUp")
        #expect(model.wasOpened(world.ana.id))
        digest.stopListening()
    }

    @Test("Follow-ups is empty when nobody is due")
    func followUpsEmpty() async throws {
        let world = try await CalendarWorld.make()
        let digest = AgendaDigestService(
            appointments: world.appointments, timeBlocks: world.timeBlocks, vault: world.vault, now: { TestClock.now }
        )
        digest.startListening()
        await Wait.untilMain { !digest.isLoading }
        let model = FollowUpsViewModel(
            settings: settings, digest: digest, bookingSetup: world.bookingSetup,
            messages: MessageService(vault: world.vault, sender: FakeMessageSender()), prefs: FixedNotificationPrefsStore()
        )

        #expect(model.phase(now: TestClock.now) == .empty)
        digest.stopListening()
    }

    // MARK: - Win back

    @Test("Win back lists whoever is away and builds the win-back message request")
    func winBack() async throws {
        let (world, digest) = try await makeWorld()
        let model = WinBackViewModel(
            settings: settings, digest: digest, bookingSetup: world.bookingSetup,
            messages: MessageService(vault: world.vault, sender: FakeMessageSender()), prefs: FixedNotificationPrefsStore()
        )
        let row = try #require(model.list(now: TestClock.now).rows.first)

        #expect(row.client.id == world.ana.id)
        #expect(model.message(for: row) == ClientMessageRequest(clientID: world.ana.id, kind: .winBack))
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

    @Test("Alerts says what the phone knows: the follow-up and the win-back counts")
    func alertsList() async throws {
        let (world, digest) = try await makeWorld()
        let model = await makeAlerts(world, digest: digest, status: .granted)
        let list = model.list(now: TestClock.now)

        #expect(list.followUpCount == 1 && list.winBackCount == 1)
        #expect(model.phase(now: TestClock.now) == .content)
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
