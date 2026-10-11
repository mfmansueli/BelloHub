//
//  AgendaRepository.swift
//  BelloHub
//

import Foundation

/// Appointments and the services they are for.
protocol AgendaRepository: Sendable {
    /// Appointments that overlap `range`, now and after every change.
    func appointments(in range: DateInterval) -> AsyncStream<[Appointment]>
    func loadAppointments(in range: DateInterval) async throws -> [Appointment]
    func appointments(for clientID: UUID) async throws -> [Appointment]
    func appointment(id: UUID) async throws -> Appointment?
    /// Every visit mirrored from a link booking (`bookingID` set), whatever its time. The booking sync finds a visit by
    /// its booking, never by a time window: a booking the client moved is no longer where its visit was.
    func linkedAppointments() async throws -> [Appointment]
    func save(_ appointment: Appointment) async throws
    func deleteAppointment(id: UUID) async throws

    func services() async throws -> [Service]
    func save(_ service: Service) async throws
    func deleteService(id: UUID) async throws
}

extension AgendaRepository {
    /// Reads the whole agenda; the SwiftData store overrides it to decode only the link visits.
    func linkedAppointments() async throws -> [Appointment] {
        try await loadAppointments(in: DateInterval(start: .distantPast, end: .distantFuture))
            .filter { $0.bookingID != nil }
    }
}
