//
//  AppointmentFixtures.swift
//  BelloHub
//

#if DEBUG
import Foundation

/// A small calendar for the visit screens: Ana with a visit in two days (reminder sent, no answer) and a plan in
/// progress, and Beatriz, whose visit started hours ago and was never closed, with one earlier no-show. Used by the
/// SwiftUI previews and by the UI-test seed `-uiSeed appointments`. The ids are fixed so a debug route can open them.
/// DEBUG only: demo data must not ship as default content.
enum AppointmentFixtures {
    struct Seeded: Equatable {
        let ana: UUID
        let beatriz: UUID
        /// Ana's visit in two days.
        let upcoming: UUID
        /// Beatriz's visit that started hours ago and is still open.
        let missed: UUID
    }

    static let seeded = Seeded(
        ana: fixed(1), beatriz: fixed(2), upcoming: fixed(0x101), missed: fixed(0x102)
    )

    @discardableResult
    static func seed(into repository: any ClientRecordRepository, now: Date) async throws -> Seeded {
        let glow = Service(name: "Brazilian Glow", durationMinutes: 90, followUpWeeks: 4)
        try await repository.save(glow)

        let ana = Client(
            id: seeded.ana, name: "Ana Costa", phoneE164: "+5511981234410", createdAt: offset(days: -200, from: now),
            importantNote: "Sensitive skin, prefers fragrance-free products", allergies: ["Fragrance"]
        )
        try await repository.save(ana)
        let plan = SessionPlan(
            id: fixed(0x201), clientID: ana.id, name: "Skin barrier repair", totalSessions: 6, intervalWeeks: 4,
            startDate: offset(days: -70, from: now), remindToRebook: true
        )
        try await repository.save(plan)
        for days in [-56, -28] {
            var done = visit(ana, glow, start: offset(days: days, from: now), status: .completed)
            done.sessionPlanID = plan.id
            try await repository.save(done)
        }
        var upcoming = visit(ana, glow, start: offset(days: 2, from: now), status: .confirmed, id: seeded.upcoming)
        upcoming.sessionPlanID = plan.id
        upcoming.reminderSentAt = offset(days: -1, from: now)
        try await repository.save(upcoming)

        let beatriz = Client(
            id: seeded.beatriz, name: "Beatriz Lima", phoneE164: "+5511970001111",
            createdAt: offset(days: -200, from: now)
        )
        try await repository.save(beatriz)
        try await repository.save(visit(beatriz, glow, start: offset(days: -10, from: now), status: .noShow))
        let started = now.addingTimeInterval(-5 * 3600)
        try await repository.save(visit(beatriz, glow, start: started, status: .booked, id: seeded.missed))
        return seeded
    }

    private static func visit(
        _ client: Client, _ service: Service, start: Date, status: AppointmentStatus, id: UUID = UUID()
    ) -> Appointment {
        Appointment(
            id: id, clientID: client.id, serviceID: service.id, serviceName: service.name, startsAt: start,
            endsAt: start.addingTimeInterval(TimeInterval(service.durationMinutes * 60)), status: status,
            createdAt: start.addingTimeInterval(-86_400 * 3)
        )
    }

    private static func offset(days: Int, from now: Date) -> Date {
        Calendar.current.date(byAdding: .day, value: days, to: now) ?? now
    }

    private static func fixed(_ number: Int) -> UUID {
        UUID(uuidString: String(format: "A9901100-0000-4000-8000-%012X", number)) ?? UUID()
    }
}
#endif
