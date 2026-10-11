//
//  VisitReader.swift
//  BelloHub
//

import Foundation

/// A visit and the client it belongs to: what every screen about one appointment starts from.
struct VisitContext: Equatable, Sendable {
    let appointment: Appointment
    let client: Client
}

/// Reads one visit with its client from the vault. A small reader, not a Service: it keeps no state, and it exists so
/// the eight screens of the visit's flow load the same pair the same way.
@MainActor
struct VisitReader {
    let appointments: AppointmentService
    let vault: VaultService

    /// Nil when the visit, or its client, no longer exists (merged, deleted). Throws when the vault cannot be read.
    func visit(id: UUID) async throws -> VisitContext? {
        guard let appointment = try await appointments.appointment(id: id) else { return nil }
        guard let repository = vault.repository else { throw VaultRepositoryError.unavailable }
        guard let client = try await repository.client(id: appointment.clientID) else { return nil }
        return VisitContext(appointment: appointment, client: client)
    }

    /// Every appointment of the client, oldest first.
    func history(of clientID: UUID) async throws -> [Appointment] {
        try await appointments.appointments(for: clientID)
    }
}
