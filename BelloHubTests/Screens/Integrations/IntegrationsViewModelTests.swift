//
//  IntegrationsViewModelTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@MainActor
@Suite("IntegrationsViewModel and CalendarIntegrationService")
struct IntegrationsViewModelTests {
    private struct World {
        let access: FakeCalendarAccess
        let settings: FakeSettingsOpener
        let viewModel: IntegrationsViewModel
        let defaults: UserDefaults
        let suite: String
    }

    private func makeWorld(access: FakeCalendarAccess) -> World {
        let suite = "integrations-vm-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite) ?? .standard
        let settings = FakeSettingsOpener()
        let viewModel = IntegrationsViewModel(
            calendar: CalendarIntegrationService(provider: access, defaults: defaults), messagingChannel: .whatsapp,
            settings: settings
        )
        return World(access: access, settings: settings, viewModel: viewModel, defaults: defaults, suite: suite)
    }

    @Test("Switching Apple Calendar on asks the iPhone once, then remembers the choice")
    func connect() async {
        let world = makeWorld(access: FakeCalendarAccess(current: .notDetermined, answer: .full))
        defer { world.defaults.removePersistentDomain(forName: world.suite) }
        let viewModel = world.viewModel
        #expect(!viewModel.appleCalendarOn)

        await viewModel.setAppleCalendarAsync(on: true)

        #expect(world.access.requests == 1)
        #expect(viewModel.appleCalendarOn)
        #expect(viewModel.summary.appleCalendar == .connected)
        #expect(world.defaults.bool(forKey: DefaultsKey.appleCalendarEnabled))

        await viewModel.setAppleCalendarAsync(on: true)
        #expect(world.access.requests == 1, "no second dialog")

        await viewModel.setAppleCalendarAsync(on: false)
        #expect(!viewModel.appleCalendarOn)
        #expect(!world.defaults.bool(forKey: DefaultsKey.appleCalendarEnabled))
    }

    @Test("A refusal leaves the switch off and the row points to Settings")
    func denied() async {
        let world = makeWorld(access: FakeCalendarAccess(current: .notDetermined, answer: .denied))
        defer { world.defaults.removePersistentDomain(forName: world.suite) }
        let viewModel = world.viewModel

        await viewModel.setAppleCalendarAsync(on: true)

        #expect(!viewModel.appleCalendarOn)
        #expect(viewModel.summary.appleCalendar == .deniedInSettings)
        viewModel.openSettings()
        #expect(world.settings.openCount == 1)
    }

    @Test("Access granted earlier but the switch off reads as available, and the import sheet is a flag")
    func availableAndImport() {
        let world = makeWorld(access: FakeCalendarAccess(current: .full))
        defer { world.defaults.removePersistentDomain(forName: world.suite) }

        #expect(world.viewModel.summary.appleCalendar == .available)
        world.viewModel.presentImport(true)
        #expect(world.viewModel.showsImport)
    }
}
