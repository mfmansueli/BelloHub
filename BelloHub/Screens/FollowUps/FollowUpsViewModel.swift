//
//  FollowUpsViewModel.swift
//  BelloHub
//

import Foundation
import Observation

/// State and actions of the follow-up queue (2.7, routine-a items 5, 6 and 12). The data is the shared digest and the
/// queue's own state (`FollowUpQueueService`); this class builds the queue at the moment the screen asks, holds the
/// filter, and records what she decides: snooze, dismiss, bring back, and "I sent it" (her own statement, never
/// presented as proof of delivery).
@MainActor
@Observable
final class FollowUpsViewModel {
    let settings: CalendarSettings
    var filter: FollowUpFilter
    var showsSetAside = false
    private(set) var errorMessage: String?

    private let source: AgendaDigestSource
    private let queueSource: FollowUpQueueSource
    private let appointments: AppointmentService
    private let inbox: BookingSyncService?
    private let now: @Sendable () -> Date

    init(
        settings: CalendarSettings, digest: AgendaDigestService, bookingSetup: BookingSetupService,
        queue: FollowUpQueueService, appointments: AppointmentService, inbox: BookingSyncService? = nil,
        filter: FollowUpFilter = .all, prefs: any NotificationPrefsStoring = DefaultsNotificationPrefsStore(),
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.settings = settings
        self.filter = filter
        self.appointments = appointments
        self.inbox = inbox
        self.now = now
        source = AgendaDigestSource(service: digest, bookingSetup: bookingSetup, settings: settings, prefs: prefs)
        queueSource = FollowUpQueueSource(digest: source, queue: queue)
    }

    // MARK: - Reading

    func queue(now: Date) -> FollowUpQueue {
        queueSource.make(now: now)
    }

    func phase(now: Date) -> ScreenPhase {
        source.phase(isEmpty: queue(now: now).isEmpty)
    }

    /// Booking and reschedule requests waiting for her answer: shown apart, with the way to Alerts.
    func requestCount(now: Date) -> Int {
        guard let inbox else { return 0 }
        let alerts = InboxAlerts.make(
            snapshot: inbox.snapshot, answering: inbox.answering, timeZone: settings.timeZone, now: now
        )
        return alerts.bookingRequests.count + alerts.reschedules.count
    }

    // MARK: - Loading

    func start() {
        source.service.startListening()
    }

    func retry() {
        Task { await refreshAsync() }
    }

    func refreshAsync() async {
        await source.service.refresh()
        await queueSource.queue.refreshLogs()
    }

    /// A chat was opened from one of the sheets: read the log again so the row says "Conversation opened".
    func chatsChanged() {
        Task { await queueSource.queue.refreshLogs() }
    }

    // MARK: - Decisions

    /// She says she sent it. A reminder keeps it on the visit (`reminderMarkedSentAt`); any other message in the
    /// queue's own decisions.
    func markSent(_ item: FollowUpItem) {
        guard item.kind == .reminder else {
            queueSource.queue.markSent(item.occurrence)
            return
        }
        guard let id = item.appointmentID else { return }
        Task {
            do {
                try await appointments.markReminderSentByHer(id: id, now: now())
                errorMessage = nil
            } catch {
                errorMessage = String(interface: LocalizedStringResource(
                    "followUpQueue.error.save",
                    defaultValue: "We could not save this. Check that your iPhone is unlocked and try again."
                ))
            }
        }
    }

    func snooze(_ item: FollowUpItem) {
        guard item.kind.canBeSetAside else { return }
        queueSource.queue.snooze(item.occurrence)
    }

    func dismiss(_ item: FollowUpItem) {
        guard item.kind.canBeSetAside else { return }
        queueSource.queue.dismiss(item.occurrence)
    }

    func restore(_ item: FollowUpItem) {
        queueSource.queue.restore(item.occurrence)
    }

    /// "Mark as done" on a visit left with Finish later: it leaves the queue (nothing about the record changes).
    func finishClosing(_ item: FollowUpItem) {
        guard let recordID = item.recordID else { return }
        queueSource.queue.complete(recordID: recordID)
    }
}
