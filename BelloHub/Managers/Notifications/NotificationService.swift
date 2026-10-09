//
//  NotificationService.swift
//  BelloHub
//

import Foundation
import Observation

/// Keeps the phone's pending local notifications in step with her calendar: next-visit reminders, birthdays, the daily
/// summary and "reminders ready". It watches the visits and the clients (`startListening` / `stopListening`), and after
/// every change asks `NotificationPlanner` for the plan and hands it to the scheduler, which replaces what was there.
///
/// Notifications are **generic**: no client or service name ever reaches the lock screen (docs/06 section 8), which the
/// planner guarantees by construction. Nothing is scheduled without the notification permission, asked for through
/// `PermissionService` (onboarding, or the Alerts tab). Her choices (quiet hours, which kinds) are read from
/// `NotificationPrefsStoring`; the settings screen writes them.
///
/// It reads the calendar for its own window (the coming days) instead of sharing `AgendaDigestService`'s stream,
/// because the two need different ranges and the planner must keep working while no screen is on.
@MainActor
@Observable
final class NotificationService {
    /// How many notifications the last plan scheduled, for the Alerts tab to say something true.
    private(set) var scheduledCount = 0

    private let appointments: AppointmentService
    private let vault: VaultService
    private let permissions: PermissionService
    private let profile: ProfileService
    private let prefs: any NotificationPrefsStoring
    private let scheduler: any NotificationScheduling
    private let now: @Sendable () -> Date
    private let listeners = TaskBag()
    private var isRescheduling = false
    private var needsAnother = false

    init(
        appointments: AppointmentService, vault: VaultService, permissions: PermissionService, profile: ProfileService,
        prefs: any NotificationPrefsStoring = DefaultsNotificationPrefsStore(),
        scheduler: any NotificationScheduling = UserNotificationScheduler(),
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.appointments = appointments
        self.vault = vault
        self.permissions = permissions
        self.profile = profile
        self.prefs = prefs
        self.scheduler = scheduler
        self.now = now
    }

    // MARK: - Listening

    /// Starts watching the calendar and the clients. Safe to call again: it restarts what runs.
    func startListening() {
        stopListening()
        guard let repository = vault.repository else { return }
        let window = DateInterval(start: now(), duration: TimeInterval(NotificationPlanner.horizonDays * 86_400))
        let visits = appointments.stream(in: window)
        let people = repository.clients()
        listeners.add([
            // The statuses are empty until read once; without this the first plan would think nothing is allowed.
            Task { [weak self] in
                await self?.permissionMayHaveChanged()
            },
            Task { [weak self] in
                for await _ in visits {
                    guard let self, !Task.isCancelled else { return }
                    await reschedule()
                }
            },
            Task { [weak self] in
                for await _ in people {
                    guard let self, !Task.isCancelled else { return }
                    await reschedule()
                }
            }
        ])
    }

    /// Stops watching. The scheduled notifications stay (a locked phone still tells her about her next visit);
    /// `removeAll()` takes them away on sign-out.
    func stopListening() {
        listeners.cancelAll()
    }

    // MARK: - Scheduling

    /// Rebuilds the plan from the calendar as it is now. A call while one is running asks for one more pass after it,
    /// so two quick changes never leave the older plan on the phone.
    func reschedule() async {
        if isRescheduling {
            needsAnother = true
            return
        }
        isRescheduling = true
        defer { isRescheduling = false }
        repeat {
            needsAnother = false
            await scheduleOnce()
        } while needsAnother
    }

    /// The permission may have changed in Settings while the app was away: read it again and reschedule.
    func permissionMayHaveChanged() async {
        await permissions.refresh()
        await reschedule()
    }

    /// Removes every notification this app scheduled (sign-out).
    func removeAll() async {
        stopListening()
        await scheduler.removeAllScheduled()
        scheduledCount = 0
    }

    // MARK: - Private

    private func scheduleOnce() async {
        guard permissions.status(of: .notifications) == .granted else {
            await scheduler.removeAllScheduled()
            scheduledCount = 0
            return
        }
        // A vault that is not open (locked, or the store failed) leaves the phone as it is: the old plan still helps her.
        guard let repository = vault.repository else { return }
        let moment = now()
        let timeZone = profile.profile.flatMap { TimeZone(identifier: $0.timeZoneID) } ?? .current
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let locale = profile.profile.flatMap { AppLocalization(rawValue: $0.appLocaleID) }?.locale ?? .current
        let window = DateInterval(start: moment, duration: TimeInterval(NotificationPlanner.horizonDays * 86_400))
        do {
            let visits = try await appointments.appointments(in: window)
            let clients = try await repository.allClients()
            let plan = NotificationPlanner.plan(
                NotificationPlanner.Input(
                    now: moment, calendar: calendar, appointments: visits, clients: clients, prefs: prefs.load()
                ),
                texts: NotificationTexts.localized(in: locale)
            )
            await scheduler.replaceScheduled(with: plan)
            scheduledCount = plan.count
        } catch {
            // The vault could not be read (locked): keep what is scheduled; the next change tries again.
        }
    }
}
