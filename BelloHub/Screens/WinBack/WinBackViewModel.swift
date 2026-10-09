//
//  WinBackViewModel.swift
//  BelloHub
//

import Foundation
import Observation

/// State and actions of Win back (2.8). The data is `AgendaDigestService`'s, shared with Home and Alerts; this class
/// starts it, builds the list and says which clients she already wrote to in this session.
@MainActor
@Observable
final class WinBackViewModel {
    let settings: CalendarSettings
    private let source: AgendaDigestSource
    private let messages: MessageService

    init(
        settings: CalendarSettings, digest: AgendaDigestService, bookingSetup: BookingSetupService,
        messages: MessageService, prefs: any NotificationPrefsStoring = DefaultsNotificationPrefsStore()
    ) {
        self.settings = settings
        self.messages = messages
        source = AgendaDigestSource(service: digest, bookingSetup: bookingSetup, settings: settings, prefs: prefs)
    }

    // MARK: - Reading

    func list(now: Date) -> WinBackList {
        WinBackList.make(from: source.digest(now: now))
    }

    func phase(now: Date) -> ScreenPhase {
        source.phase(isEmpty: list(now: now).isEmpty)
    }

    func wasOpened(_ clientID: UUID) -> Bool {
        messages.recentlyOpened[clientID] != nil
    }

    // MARK: - Actions

    func start() {
        source.service.startListening()
    }

    func retry() {
        Task { await refreshAsync() }
    }

    func refreshAsync() async {
        await source.service.refresh()
    }

    func message(for row: WinBackList.Row) -> ClientMessageRequest {
        ClientMessageRequest(clientID: row.client.id, kind: .winBack)
    }
}
