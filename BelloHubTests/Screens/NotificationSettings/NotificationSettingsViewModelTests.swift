//
//  NotificationSettingsViewModelTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@MainActor
@Suite("NotificationSettingsViewModel")
struct NotificationSettingsViewModelTests {
    private struct World {
        let store: FakeNotificationPrefsStore
        let permissions: FakePermissionProvider
        let settings: FakeSettingsOpener
        let viewModel: NotificationSettingsViewModel
        let defaults: UserDefaults
        let suite: String
    }

    private func makeWorld(answer: PermissionStatus = .granted) -> World {
        let suite = "notification-vm-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite) ?? .standard
        let store = FakeNotificationPrefsStore()
        let permissions = FakePermissionProvider(answers: [.notifications: answer])
        let settings = FakeSettingsOpener()
        let service = NotificationSettingsService(
            store: store, permissions: PermissionService(provider: permissions), defaults: defaults
        )
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Lisbon") ?? .current
        let viewModel = NotificationSettingsViewModel(service: service, settings: settings, calendar: calendar)
        return World(
            store: store, permissions: permissions, settings: settings, viewModel: viewModel, defaults: defaults,
            suite: suite
        )
    }

    @Test("Every switch saves at once; the published value changes only after the store confirmed")
    func switches() {
        let world = makeWorld()
        defer { world.defaults.removePersistentDomain(forName: world.suite) }
        let viewModel = world.viewModel
        #expect(viewModel.prefs == .standard)

        viewModel.update { $0.birthdays = false }
        #expect(!viewModel.prefs.birthdays)
        #expect(world.store.stored?.birthdays == false)

        world.store.failsSaves = true
        viewModel.update { $0.newBookings = false }
        #expect(viewModel.prefs.newBookings, "a failed save leaves the switch where it was")
        #expect(viewModel.errorMessage != nil)

        world.store.failsSaves = false
        viewModel.update { $0.newBookings = false }
        #expect(viewModel.errorMessage == nil)
        #expect(world.store.saveCount == 3)
    }

    @Test("Quiet hours switch on with the default window and the pickers move its edges")
    func quietHours() {
        let world = makeWorld()
        defer { world.defaults.removePersistentDomain(forName: world.suite) }
        let viewModel = world.viewModel
        #expect(!viewModel.quietHoursOn)

        viewModel.setQuietHours(on: true)
        #expect(viewModel.quietHoursOn)
        #expect(viewModel.prefs.quietHours == NotificationSettingsRules.defaultQuietHours)

        viewModel.setQuietFrom(NotificationSettingsRules.date(forMinutes: 21 * 60, calendar: viewModel.calendar))
        viewModel.setQuietUntil(NotificationSettingsRules.date(forMinutes: 8 * 60, calendar: viewModel.calendar))
        #expect(viewModel.prefs.quietHours == QuietHoursWindow(fromMinutes: 21 * 60, untilMinutes: 8 * 60))
        #expect(NotificationSettingsRules.minutes(of: viewModel.quietFrom, calendar: viewModel.calendar) == 21 * 60)

        viewModel.setReminderTime(NotificationSettingsRules.date(forMinutes: 19 * 60, calendar: viewModel.calendar))
        #expect(viewModel.prefs.reminderTimeMinutes == 19 * 60)

        viewModel.setQuietHours(on: false)
        #expect(viewModel.prefs.quietHours == nil)
    }

    @Test("The permission is asked once through the system, and a refusal points to Settings")
    func permission() async {
        let world = makeWorld(answer: .denied)
        defer { world.defaults.removePersistentDomain(forName: world.suite) }
        let viewModel = world.viewModel
        await viewModel.refresh()
        #expect(viewModel.permission == .ask)

        await viewModel.askPermissionAsync()

        #expect(world.permissions.requested == [.notifications])
        #expect(viewModel.permission == .denied)
        viewModel.openSettings()
        #expect(world.settings.openCount == 1)
    }
}
