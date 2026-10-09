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

    // MARK: - Private

    private func change(_ id: UUID, _ transition: (Appointment) -> Appointment) async throws -> Appointment {
        let repository = try requireRepository()
        guard let current = try await repository.appointment(id: id) else { throw VaultRepositoryError.notFound }
        let changed = transition(current)
        try await repository.save(changed)
        return changed
    }

    private func requireRepository() throws -> any AgendaRepository {
        guard let repository = source() else { throw VaultRepositoryError.unavailable }
        return repository
    }
}
