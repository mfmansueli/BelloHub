//
//  CalendarIntegrationService.swift
//  BelloHub
//

import Foundation
import Observation

/// Apple Calendar on and off (7.6), and the write-through of her visits into a "Bello Hub" calendar on this iPhone.
/// "Connected" means she switched it on **and** the iPhone allows writing; the switch is remembered in `UserDefaults`
/// (a preference, not client data).
///
/// The calendar is a mirror of the vault, never a source: while she is signed in and unlocked it watches her visits
/// (`startListening` / `stopListening`) and, after every change, asks `CalendarEventPlanner` what differs and hands
/// that to the writer. It needs full access, because a mirror has to read back what it wrote; with write-only access
/// the switch stays on but nothing is written. Switching it off or signing out removes the "Bello Hub" calendar.
@MainActor
@Observable
final class CalendarIntegrationService {
    private(set) var access: CalendarAccessStatus
    private(set) var isEnabled: Bool

    @ObservationIgnored private let provider: any CalendarAccessProviding
    @ObservationIgnored private let writer: any CalendarEventWriting
    @ObservationIgnored private let appointments: AppointmentService?
    @ObservationIgnored private let vault: VaultService?
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let now: @Sendable () -> Date
    @ObservationIgnored private let listeners = TaskBag()
    @ObservationIgnored private var isSyncing = false
    @ObservationIgnored private var needsAnother = false

    /// `appointments` and `vault` are the visits to mirror; without them (the Integrations screen's tests and previews)
    /// only the switch and the access are handled.
    init(
        provider: any CalendarAccessProviding = EventKitCalendarAccess(),
        writer: any CalendarEventWriting = EventKitCalendarWriter(),
        appointments: AppointmentService? = nil, vault: VaultService? = nil, defaults: UserDefaults = .standard,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.provider = provider
        self.writer = writer
        self.appointments = appointments
        self.vault = vault
        self.defaults = defaults
        self.now = now
        access = provider.status()
        isEnabled = defaults.bool(forKey: DefaultsKey.appleCalendarEnabled)
    }

    var isConnected: Bool { isEnabled && access.canWrite }

    func refresh() {
        access = provider.status()
    }

    // MARK: - Switch

    /// Switches the sync on: asks the iPhone first when it never did, then writes her visits. Returns whether it is
    /// connected afterwards.
    @discardableResult
    func connect() async -> Bool {
        if access == .notDetermined { access = await provider.requestFullAccess() }
        guard access.canWrite else {
            isEnabled = false
            return false
        }
        isEnabled = true
        defaults.set(true, forKey: DefaultsKey.appleCalendarEnabled)
        await sync()
        // Switching off stopped the watch (`removeMirror`); switching on again resumes it without a relaunch.
        startListening()
        return true
    }

    /// Switches the sync off and takes the "Bello Hub" calendar away.
    func disconnect() {
        isEnabled = false
        defaults.set(false, forKey: DefaultsKey.appleCalendarEnabled)
        Task { await removeMirror() }
    }

    // MARK: - Write-through

    /// Starts watching her visits. Safe to call again: it restarts what runs.
    func startListening() {
        stopListening()
        guard let appointments else { return }
        let visits = appointments.stream(in: CalendarEventPlanner.window(now: now()))
        listeners.add([
            Task { [weak self] in
                for await _ in visits {
                    guard let self, !Task.isCancelled else { return }
                    await sync()
                }
            }
        ])
    }

    /// Stops watching. The events stay (a locked phone still shows her day); `removeMirror()` takes them away.
    func stopListening() {
        listeners.cancelAll()
    }

    /// Brings the "Bello Hub" calendar in line with her visits. A call while one runs asks for one more pass after
    /// it, so two quick changes never leave the older state in the calendar.
    func sync() async {
        if isSyncing {
            needsAnother = true
            return
        }
        isSyncing = true
        defer { isSyncing = false }
        repeat {
            needsAnother = false
            await syncOnce()
        } while needsAnother
    }

    /// Removes the "Bello Hub" calendar and its events (switched off, signed out, account deleted).
    func removeMirror() async {
        stopListening()
        do {
            try await writer.removeCalendar()
        } catch {
            // Nothing to undo: the calendar stays until the next removal, and she can delete it in Calendar.
        }
    }

    // MARK: - Private

    private func syncOnce() async {
        refresh()
        // Full access only: a mirror must read back what it wrote, or every pass would add the visits again.
        guard isEnabled, access == .full, let appointments, let repository = vault?.repository else { return }
        let window = CalendarEventPlanner.window(now: now())
        do {
            let visits = try await appointments.appointments(in: window)
            let names = Dictionary(
                try await repository.allClients().map { ($0.id, $0.name) }, uniquingKeysWith: { first, _ in first }
            )
            let drafts = CalendarEventPlanner.drafts(
                appointments: visits, clientNames: names,
                showsNames: !NotificationSettingsService.hidesNames(in: defaults),
                genericTitle: String(localized: "integrations.apple.eventTitle")
            )
            let existing = try await writer.events(in: window)
            try await writer.apply(CalendarEventPlanner.changes(drafts: drafts, existing: existing))
        } catch {
            // The vault is locked or the calendar refused the write: nothing is half-applied (one commit), and the
            // next change in her calendar tries again.
        }
    }
}
