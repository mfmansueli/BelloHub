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
    /// The follow-up queue, summarized in one card; nil in tests that only check the rest.
    private let queueSource: FollowUpQueueSource?
    /// What arrives through her link (S8); nil in tests that only check the local part.
    private let inbox: BookingSyncService?
    /// The sealed mailbox (S8); nil in tests that only check the local part.
    private let mailbox: MailboxService?
    private let permissions: PermissionService
    private let notifications: NotificationService
    private let settingsOpener: any SettingsOpening

    init(
        settings: CalendarSettings, digest: AgendaDigestService, bookingSetup: BookingSetupService,
        permissions: PermissionService, notifications: NotificationService,
        settingsOpener: any SettingsOpening = SystemSettingsOpener(),
        prefs: any NotificationPrefsStoring = DefaultsNotificationPrefsStore(),
        inbox: BookingSyncService? = nil,
        mailbox: MailboxService? = nil,
        queue: FollowUpQueueService? = nil
    ) {
        self.settings = settings
        self.inbox = inbox
        self.mailbox = mailbox
        self.permissions = permissions
        self.notifications = notifications
        self.settingsOpener = settingsOpener
        let source = AgendaDigestSource(service: digest, bookingSetup: bookingSetup, settings: settings, prefs: prefs)
        self.source = source
        queueSource = queue.map { FollowUpQueueSource(digest: source, queue: $0) }
    }

    // MARK: - Reading

    func list(now: Date) -> AlertsList {
        AlertsList.make(from: source.digest(now: now))
    }

    /// Clients with something in the follow-up queue (reminders, visits to close, check-ins, returns, not back,
    /// birthdays).
    func reachOutCount(now: Date) -> Int {
        queueSource?.make(now: now).count(.all) ?? 0
    }

    /// Records still owed: completed bookings with nothing written, and drafts. The same list as Home's.
    func records(now: Date) -> RecordPending {
        source.records(now: now)
    }

    var clientNames: [UUID: String] { source.clientNames }

    /// Requests and the waitlist from the server; empty when there is no inbox.
    func inboxAlerts(now: Date) -> InboxAlerts {
        guard let inbox else { return .empty }
        return InboxAlerts.make(
            snapshot: inbox.snapshot, answering: inbox.answering, timeZone: settings.timeZone, now: now
        )
    }

    /// What her clients sent through the sealed mailbox; empty when there is no mailbox.
    var mailboxAlerts: MailboxAlerts {
        guard let mailbox else { return .empty }
        return MailboxAlerts.make(
            messages: mailbox.messages, undecryptable: mailbox.undecryptable, imports: mailbox.imports
        )
    }

    func phase(now: Date) -> ScreenPhase {
        source.phase(
            isEmpty: list(now: now).isEmpty && reachOutCount(now: now) == 0 && inboxAlerts(now: now).isEmpty
                && mailboxAlerts.isEmpty && records(now: now).isEmpty
        )
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
        await mailbox?.syncAsync()
        await permissions.refresh()
    }

    /// She dealt with a check-in or a request, or gave up on an item that does not open: either way it leaves the
    /// list and is acknowledged on the server, so nothing a client sent stays unanswered there.
    func resolve(_ item: MailboxAlerts.Item) {
        if item.isMessage {
            mailbox?.markHandled(messageID: item.id)
        } else {
            mailbox?.dismissUndecryptable(id: item.id)
        }
    }

    func markImportsSeen() {
        mailbox?.markImportsSeen()
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
