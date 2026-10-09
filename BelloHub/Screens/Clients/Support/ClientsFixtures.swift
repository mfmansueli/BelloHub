//
//  ClientsFixtures.swift
//  BelloHub
//

#if DEBUG
import Foundation

/// The prototype's demo clients (docs/05-DATA-MODEL.md section 4) for the DEBUG launch seed `-uiSeed clients` and for
/// SwiftUI previews. Dates are relative to `now`, so "last visit 35 days ago" stays true whenever it runs. Never
/// compiled into Release: demo data must not ship as default content.
enum ClientsFixtures {
    /// What the seed created, so a preview or a test can open a particular client.
    struct Seeded {
        let ana: UUID
        let beatriz: UUID
        let helena: UUID
        let archived: UUID
    }

    @discardableResult
    static func seed(into repository: any ClientRecordRepository, now: Date) async throws -> Seeded {
        let glow = Service(name: "Glow Facial", durationMinutes: 60, followUpWeeks: 4)
        let deep = Service(name: "Deep Cleansing", durationMinutes: 75, followUpWeeks: 6, position: 1)
        try await repository.save(glow)
        try await repository.save(deep)
        let tags = try await repository.tags().map(\.id)

        let ana = try await saveAna(into: repository, glow: glow, tags: Array(tags.prefix(1)), now: now)
        let beatriz = try await saveBeatriz(into: repository, glow: glow, now: now)
        let helena = Client(name: "Helena Duarte", createdAt: day(-3, from: now))
        try await repository.save(helena)
        try await repository.save(appointment(helena, glow, daysFromNow: 4, status: .booked, now: now))

        let camila = Client(name: "Camila Rocha", phoneE164: "+5511955550003", tagIDs: Array(tags.prefix(2)),
                            createdAt: day(-300, from: now))
        try await repository.save(camila)
        for offset in [-12, -50] { try await repository.save(appointment(camila, glow, daysFromNow: offset, now: now)) }

        let others = [("Fernanda Lopes", -45), ("Gisele Matos", -30), ("Paula Nunes", -80), ("Marina Souza", -70)]
        for (name, offset) in others {
            let client = Client(name: name, createdAt: day(-300, from: now))
            try await repository.save(client)
            try await repository.save(appointment(client, glow, daysFromNow: offset, now: now))
        }
        let archived = Client(name: "Julia Mendes", isArchived: true, createdAt: day(-400, from: now))
        try await repository.save(archived)
        return Seeded(ana: ana.id, beatriz: beatriz.id, helena: helena.id, archived: archived.id)
    }

    /// Ana: five visits, a session plan in progress, a private note and what she remembers, next visit in three days.
    private static func saveAna(
        into repository: any ClientRecordRepository, glow: Service, tags: [UUID], now: Date
    ) async throws -> Client {
        var ana = Client(
            name: "Ana Costa", phoneE164: "+5511981234410", email: "ana@example.com", tagIDs: tags,
            createdAt: day(-400, from: now), importantNote: "Sensitive skin, prefers fragrance-free products",
            allergies: ["Fragrance"], sensitivities: ["Cheeks"], preferences: ["Fragrance-free"],
            recurringRequests: ["Gentle pressure"]
        )
        ana.birthday = Birthday(month: 3, day: 14, year: nil)
        try await repository.save(ana)
        let plan = SessionPlan(
            id: UUID(), clientID: ana.id, name: "Skin barrier repair", totalSessions: 6, intervalWeeks: 4,
            startDate: day(-110, from: now), remindToRebook: true
        )
        try await repository.save(plan)
        for (index, offset) in [-35, -70, -105, -140, -175].enumerated() {
            var visit = appointment(ana, glow, daysFromNow: offset, now: now)
            if index < 3 { visit.sessionPlanID = plan.id }
            try await repository.save(visit)
        }
        try await repository.save(appointment(ana, glow, daysFromNow: -20, status: .cancelled, now: now))
        try await repository.save(appointment(ana, glow, daysFromNow: 3, status: .confirmed, now: now))
        try await repository.save(ConsentRecord(
            id: UUID(), clientID: ana.id, kind: .treatment, isSigned: true, signedAt: day(-175, from: now),
            createdAt: day(-175, from: now), label: "Facial treatments, paper form"
        ))
        return ana
    }

    /// Beatriz: cancels often (four visits, three cancellations, two of them late).
    private static func saveBeatriz(
        into repository: any ClientRecordRepository, glow: Service, now: Date
    ) async throws -> Client {
        let beatriz = Client(name: "Beatriz Lima", phoneE164: "+5511970001111", createdAt: day(-300, from: now))
        try await repository.save(beatriz)
        for offset in [-120, -105, -90, -75] {
            try await repository.save(appointment(beatriz, glow, daysFromNow: offset, now: now))
        }
        for (index, offset) in [-60, -45, -30].enumerated() {
            var cancelled = appointment(beatriz, glow, daysFromNow: offset, status: .cancelled, now: now)
            cancelled.cancelledBy = .client
            cancelled.isLateCancellation = index < 2
            try await repository.save(cancelled)
        }
        return beatriz
    }

    private static func day(_ offset: Int, from now: Date) -> Date {
        Calendar.current.date(byAdding: .day, value: offset, to: now) ?? now
    }

    private static func appointment(
        _ client: Client, _ service: Service, daysFromNow: Int, status: AppointmentStatus = .completed, now: Date
    ) -> Appointment {
        let calendar = Calendar.current
        let start = calendar.date(
            bySettingHour: 15, minute: 0, second: 0, of: day(daysFromNow, from: now)
        ) ?? day(daysFromNow, from: now)
        return Appointment(
            clientID: client.id, serviceID: service.id, serviceName: service.name, startsAt: start,
            endsAt: start.addingTimeInterval(TimeInterval(service.durationMinutes * 60)), status: status,
            cancelledBy: status == .cancelled ? .client : nil, createdAt: start
        )
    }
}
#endif
