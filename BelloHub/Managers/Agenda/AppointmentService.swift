//
//  AppointmentService.swift
//  BelloHub
//

import Foundation
import Observation

/// The calendar's writes and reads, in one place: every screen that books, moves, cancels or closes a visit goes
/// through it, so the rules in `AppointmentTransitions` are applied once and a failed write never half-changes a visit.
/// It keeps no copy of the calendar: screens that show a range read `stream(in:)` (the vault pushes every change) or
/// `appointments(in:)`, so there is nothing to clear on lock or sign-out.
@MainActor
@Observable
final class AppointmentService {
    /// Looked up on each use, because the vault may be unavailable (nil) when the store could not be opened.
    private let source: @MainActor () -> (any AgendaRepository)?
    /// Hears every change she makes to a visit that came from her link, so the server booking follows
    /// (`BookingSyncService` sets itself here). Nil in previews and screens without a server.
    @ObservationIgnored weak var linkChanges: (any LinkVisitChangeReporting)?

    init(vault: VaultService) {
        source = { vault.repository }
    }

    init(repository: any AgendaRepository) {
        source = { repository }
    }

    // MARK: - Reading

    /// Appointments that overlap `range`, now and after every change; empty when the vault is unavailable.
    func stream(in range: DateInterval) -> AsyncStream<[Appointment]> {
        source()?.appointments(in: range) ?? AsyncStream { $0.finish() }
    }

    func appointments(in range: DateInterval) async throws -> [Appointment] {
        try await requireRepository().loadAppointments(in: range)
    }

    func appointments(for clientID: UUID) async throws -> [Appointment] {
        try await requireRepository().appointments(for: clientID)
    }

    func appointment(id: UUID) async throws -> Appointment? {
        try await requireRepository().appointment(id: id)
    }

    // MARK: - Writing

    /// Stores a new visit (the screens have already shown her any warnings; booking is her decision).
    func book(_ appointment: Appointment) async throws {
        try await requireRepository().save(appointment)
    }

    /// Associates a manual visit with its server booking after registration succeeds. Keep the original visit id,
    /// so a later inbox sync updates this visit rather than creating a second calendar entry.
    func linkManualBooking(id: UUID, bookingID: String) async throws {
        let repository = try requireRepository()
        guard var visit = try await repository.appointment(id: id), visit.origin == .manual else {
            throw VaultRepositoryError.notFound
        }
        guard visit.bookingID == nil || visit.bookingID == bookingID else { return }
        visit.bookingID = bookingID
        try await repository.save(visit)
    }

    @discardableResult
    func reschedule(id: UUID, to start: Date, now: Date = Date()) async throws -> Appointment {
        try await change(id) { AppointmentTransitions.rescheduled($0, to: start, now: now) }
    }

    /// `policy` is the one that applied when the visit was booked (a snapshot), never today's policy (D47).
    @discardableResult
    func cancel(
        id: UUID, by who: CancelledBy, policy: CancellationPolicy, now: Date = Date()
    ) async throws -> Appointment {
        try await change(id) { AppointmentTransitions.cancelled($0, by: who, policy: policy, now: now) }
    }

    @discardableResult
    func markNoShow(id: UUID, forgive: Bool, now: Date = Date()) async throws -> Appointment {
        try await change(id) { AppointmentTransitions.noShow($0, forgive: forgive, now: now) }
    }

    @discardableResult
    func complete(id: UUID, now: Date = Date()) async throws -> Appointment {
        try await change(id) { AppointmentTransitions.completed($0, now: now) }
    }

    @discardableResult
    func reportLate(id: UUID, byMinutes minutes: Int, now: Date = Date()) async throws -> Appointment {
        try await change(id) { AppointmentTransitions.late($0, byMinutes: minutes, now: now) }
    }

    /// Remembers that she opened a reminder chat for the visit (D31: "Reminders ready" then shows it as opened). The
    /// app never sends by itself, so this means "she was about to send".
    @discardableResult
    func markReminderSent(id: UUID, now: Date = Date()) async throws -> Appointment {
        try await change(id) {
            var visit = $0
            visit.reminderSentAt = now
            visit.updatedAt = now
            return visit
        }
    }

    /// Records that she says she sent the reminder herself (routine-a item 6). The app never sees WhatsApp, so this is
    /// her statement, kept apart from `reminderSentAt` (the chat was opened) and shown as "marked as sent by you".
    @discardableResult
    func markReminderSentByHer(id: UUID, now: Date = Date()) async throws -> Appointment {
        try await change(id) {
            var visit = $0
            visit.reminderMarkedSentAt = now
            visit.updatedAt = now
            return visit
        }
    }

    // MARK: - Private

    private func change(_ id: UUID, _ transition: (Appointment) -> Appointment) async throws -> Appointment {
        let repository = try requireRepository()
        guard let current = try await repository.appointment(id: id) else { throw VaultRepositoryError.notFound }
        let changed = transition(current)
        try await repository.save(changed)
        // Only after the vault took it: a failed save changes nothing anywhere.
        if let change = LinkVisitChange.change(from: current, to: changed) { linkChanges?.linkVisitChanged(change) }
        return changed
    }

    private func requireRepository() throws -> any AgendaRepository {
        guard let repository = source() else { throw VaultRepositoryError.unavailable }
        return repository
    }
}
