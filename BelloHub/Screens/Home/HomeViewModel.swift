//
//  HomeViewModel.swift
//  BelloHub
//

import Foundation
import Observation

/// State and actions of Home (2.1). The data is `AgendaDigestService`'s and the follow-up queue's (one observation
/// shared with Alerts and the queue); this class starts them, reads her hours, and turns the raw data into the day at
/// the moment the screen asks, so "in 1 h 20 min" stays true as the minutes pass (routine-a item 4: next visit, today's
/// pending items and the agenda first; one secondary card for everyone to reach out to).
@MainActor
@Observable
final class HomeViewModel {
    let settings: CalendarSettings
    private let source: AgendaDigestSource
    private let queueSource: FollowUpQueueSource
    private let bookingSetup: BookingSetupService
    /// Booking requests from the server; nil in tests that only check the local part.
    private let inbox: BookingSyncService?
    private let permissions: PermissionService?
    private let notifications: NotificationService?

    init(
        settings: CalendarSettings, digest: AgendaDigestService, bookingSetup: BookingSetupService,
        queue: FollowUpQueueService, inbox: BookingSyncService? = nil, permissions: PermissionService? = nil,
        notifications: NotificationService? = nil,
        prefs: any NotificationPrefsStoring = DefaultsNotificationPrefsStore()
    ) {
        self.settings = settings
        self.bookingSetup = bookingSetup
        self.inbox = inbox
        self.permissions = permissions
        self.notifications = notifications
        source = AgendaDigestSource(service: digest, bookingSetup: bookingSetup, settings: settings, prefs: prefs)
        queueSource = FollowUpQueueSource(digest: source, queue: queue)
    }

    // MARK: - Reading

    func digest(now: Date) -> AgendaDigest {
        source.digest(now: now)
    }

    func pending(digest: AgendaDigest, now: Date) -> HomePending {
        let requests = inbox.map {
            InboxAlerts.make(snapshot: $0.snapshot, answering: $0.answering, timeZone: settings.timeZone, now: now)
        }
        return HomePending.make(
            queue: queueSource.make(now: now),
            requestCount: (requests?.bookingRequests.count ?? 0) + (requests?.reschedules.count ?? 0),
            notificationsUndecided: permissions?.status(of: .notifications) == .notDetermined,
            hasUpcomingVisit: digest.nextVisit != nil
        )
    }

    /// Records still owed: completed bookings with nothing written, and drafts (`RecordPending`).
    func records(now: Date) -> RecordPending {
        source.records(now: now)
    }

    var clientNames: [UUID: String] { source.clientNames }

    func reachOut(now: Date) -> HomeReachOut {
        HomeReachOut.make(queue: queueSource.make(now: now))
    }

    /// Loading until the visits arrived once, an error when the vault is not available, otherwise content (an empty day
    /// is a state of the content, because the queue below may still have something to say).
    var phase: ScreenPhase {
        source.phase(isEmpty: false)
    }

    // MARK: - Actions

    /// Starts the observation and reads her hours (for the open slots of the week).
    func start() {
        source.service.startListening()
        Task { await loadHours() }
        Task { await permissions?.refresh() }
    }

    func retry() {
        Task { await refreshAsync() }
    }

    func refreshAsync() async {
        await source.service.refresh()
        await queueSource.queue.refreshLogs()
        await loadHours()
    }

    /// The system dialog, asked now that a visit is coming; when she agrees, the visit reminders are scheduled at once.
    func turnOnNotifications() {
        Task {
            guard await permissions?.request(.notifications) == .granted else { return }
            await notifications?.reschedule()
        }
    }

    // MARK: - Private

    private func loadHours() async {
        try? await bookingSetup.load(timeZoneID: settings.timeZoneID)
    }
}
