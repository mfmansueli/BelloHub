//
//  FollowUpsViewModel.swift
//  BelloHub
//

import Foundation
import Observation

/// State and actions of Follow-ups (2.7). The data is `AgendaDigestService`'s, shared with Home and Alerts; this class
/// starts it, builds the list the screen shows and says which clients she already wrote to in this session.
@MainActor
@Observable
final class FollowUpsViewModel {
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

    func list(now: Date) -> FollowUpsList {
        FollowUpsList.make(from: source.digest(now: now))
    }

    func phase(now: Date) -> ScreenPhase {
        source.phase(isEmpty: list(now: now).isEmpty)
    }

    /// She opened a chat for this client during this session.
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

    /// The request for a follow-up message to a client.
    func message(for row: FollowUpsList.DueRow) -> ClientMessageRequest {
        ClientMessageRequest(clientID: row.client.id, kind: .followUp(serviceName: row.followUp.serviceName))
    }

    func wishes(for row: FollowUpsList.BirthdayRow) -> ClientMessageRequest {
        ClientMessageRequest(clientID: row.client.id, kind: .birthday)
    }
}
