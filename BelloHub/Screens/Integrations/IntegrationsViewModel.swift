//
//  IntegrationsViewModel.swift
//  BelloHub
//

import Foundation
import Observation

/// State and actions of Integrations (7.6): Apple Calendar on and off (with the system's access flow), and the
/// states of the other rows.
@MainActor
@Observable
final class IntegrationsViewModel {
    private(set) var isConnecting = false
    private(set) var showsImport = false

    private let calendar: CalendarIntegrationService
    private let settings: any SettingsOpening
    private let messagingChannel: MessagingChannel?

    init(
        calendar: CalendarIntegrationService, messagingChannel: MessagingChannel?,
        settings: any SettingsOpening = SystemSettingsOpener()
    ) {
        self.calendar = calendar
        self.messagingChannel = messagingChannel
        self.settings = settings
    }

    var summary: IntegrationsSummary {
        IntegrationsSummary(
            calendarAccess: calendar.access, calendarEnabled: calendar.isEnabled, messagingChannel: messagingChannel
        )
    }

    var appleCalendarOn: Bool { calendar.isConnected }

    func refresh() {
        calendar.refresh()
    }

    func setAppleCalendar(on: Bool) {
        Task { await setAppleCalendarAsync(on: on) }
    }

    func setAppleCalendarAsync(on: Bool) async {
        guard !isConnecting else { return }
        if on {
            isConnecting = true
            defer { isConnecting = false }
            await calendar.connect()
        } else {
            calendar.disconnect()
        }
    }

    func openSettings() {
        settings.openSettings()
    }

    func presentImport(_ presented: Bool) {
        showsImport = presented
    }
}
