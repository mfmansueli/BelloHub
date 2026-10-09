//
//  AlertsViewModel.swift
//  BelloHub
//

import Foundation
import Observation

/// State and actions of the Alerts tab (2.4), local part: the list worked out from the shared digest, and the state of
/// the notification permission (asked through `PermissionService`; when it was refused, Settings is the only way back,
/// so the tab says so and offers it). The scheduling itself is `NotificationService`'s.
@MainActor
@Observable
final class AlertsViewModel {
    /// What the permission strip says.
    enum PermissionNotice: Equatable, Sendable {
        /// Notifications are on: no strip.
        case none
        /// She has not been asked yet.
        case ask
        /// She said no: only Settings can change it.
        case denied
    }

    let settings: CalendarSettings
    private let source: AgendaDigestSource
    /// What arrives through her link (S8); nil in tests that only check the local part.
    private let inbox: BookingSyncService?
    private let permissions: PermissionService
    private let notifications: NotificationService
    private let settingsOpener: any SettingsOpening

    init(
        settings: CalendarSettings, digest: AgendaDigestService, bookingSetup: BookingSetupService,
        permissions: PermissionService, notifications: NotificationService,
        settingsOpener: any SettingsOpening = SystemSettingsOpener(),
        prefs: any NotificationPrefsStoring = DefaultsNotificationPrefsStore(),
        inbox: BookingSyncService? = nil
    ) {
        self.settings = settings
        self.inbox = inbox
        self.permissions = permissions
        self.notifications = notifications
        self.settingsOpener = settingsOpener
        source = AgendaDigestSource(service: digest, bookingSetup: bookingSetup, settings: settings, prefs: prefs)
    }

    // MARK: - Reading

    func list(now: Date) -> AlertsList {
        AlertsList.make(from: source.digest(now: now))
    }

    /// Requests and the waitlist from the server; empty when there is no inbox.
    func inboxAlerts(now: Date) -> InboxAlerts {
        guard let inbox else { return .empty }
        return InboxAlerts.make(
            snapshot: inbox.snapshot, answering: inbox.answering, timeZone: settings.timeZone, now: now
        )
    }

    func phase(now: Date) -> ScreenPhase {
        source.phase(isEmpty: list(now: now).isEmpty && inboxAlerts(now: now).isEmpty)
    }

    var notice: PermissionNotice {
        switch permissions.status(of: .notifications) {
        case .granted: .none
        case .notDetermined: .ask
        case .denied: .denied
        }
    }

    // MARK: - Actions

    func start() {
        source.service.startListening()
        Task { await permissions.refresh() }
    }

    func retry() {
        Task { await refreshAsync() }
    }

    func refreshAsync() async {
        await source.service.refresh()
        await inbox?.syncAsync()
        await permissions.refresh()
    }

    /// Shows the system dialog and, when she agrees, schedules the notifications at once.
    func turnOnNotifications() {
        Task { await turnOnNotificationsAsync() }
    }

    func turnOnNotificationsAsync() async {
        guard await permissions.request(.notifications) == .granted else { return }
        await notifications.reschedule()
    }

    func openSettings() {
        settingsOpener.openSettings()
    }
}
