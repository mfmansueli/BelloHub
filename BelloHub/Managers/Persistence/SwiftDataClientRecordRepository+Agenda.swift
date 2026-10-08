//
//  SwiftDataClientRecordRepository+Agenda.swift
//  BelloHub
//

import Foundation

extension SwiftDataClientRecordRepository {
    nonisolated func appointments(in range: DateInterval) -> AsyncStream<[Appointment]> {
        changes.stream { [self] in (try? await loadAppointments(in: range)) ?? [] }
    }

    func loadAppointments(in range: DateInterval) throws -> [Appointment] {
        // Filter on the clear index columns first, so only the appointments in range are decoded.
        let inRange = try items(kind: .appointment).filter { item in
            guard let start = item.dateA, let end = item.dateB else { return false }
            return start < range.end && end > range.start
        }
        return try values(Appointment.self, from: inRange).sorted { $0.startsAt < $1.startsAt }
    }

    func appointments(for clientID: UUID) throws -> [Appointment] {
        try values(Appointment.self, from: items(kind: .appointment, ownerID: clientID))
            .sorted { $0.startsAt < $1.startsAt }
    }

    func appointment(id: UUID) throws -> Appointment? {
        try item(kind: .appointment, id: id).map { try value(Appointment.self, from: $0) }
    }

    func save(_ appointment: Appointment) throws {
        var stored = appointment
        stored.updatedAt = clock()
        try upsert(stored)
        try commit()
    }

    func deleteAppointment(id: UUID) throws {
        if let found = try item(kind: .appointment, id: id) { delete([found]) }
        try commit()
    }

    func services() throws -> [Service] {
        try values(Service.self, from: items(kind: .service)).sorted { ($0.position, $0.name) < ($1.position, $1.name) }
    }

    func save(_ service: Service) throws {
        try upsert(service)
        try commit()
    }

    func deleteService(id: UUID) throws {
        if let found = try item(kind: .service, id: id) { delete([found]) }
        try commit()
    }
}
