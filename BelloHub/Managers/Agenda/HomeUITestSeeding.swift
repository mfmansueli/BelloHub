//
//  HomeUITestSeeding.swift
//  BelloHub
//

#if DEBUG
import Foundation

/// What `-uiHome` adds before the app starts, relative to the moment of launch and in the business time zone
/// (America/Sao_Paulo, the one the `onboarded` seed uses), so Home has something to show at any hour of the day:
/// Julia's visit earlier today (completed), Camila's in half an hour (the next one), Ana's in three hours (a reminder
/// is always ready for it: the evening before has passed), Beatriz who has not been back for three months (a follow-up
/// and a win-back) and Larissa whose birthday is tomorrow. It goes with `-uiSeed onboarded` (the profile and the
/// services). DEBUG only.
enum HomeUITestSeeding {
    static let argument = "-uiHome"
    static let timeZoneID = "America/Sao_Paulo"

    static let julia = fixed(1)
    static let camila = fixed(2)
    static let ana = fixed(3)
    static let beatriz = fixed(4)
    static let larissa = fixed(5)
    /// Julia's visit earlier today, so a test can open it from "The rest of today".
    static let juliaVisit = fixed(0x101)
    static let camilaVisit = fixed(0x102)
    static let anaVisit = fixed(0x103)

    @MainActor
    static func seedIfRequested(
        _ dependencies: AppDependencies, arguments: [String] = ProcessInfo.processInfo.arguments
    ) async {
        guard arguments.contains(argument), let repository = dependencies.vault.repository else { return }
        await seed(into: repository, now: Date())
    }

    static func seed(into repository: any ClientRecordRepository, now: Date) async {
        let timeZone = TimeZone(identifier: timeZoneID) ?? .current
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let today = calendar.startOfDay(for: now)
        let glow = Service(name: "Glow Facial", durationMinutes: 60, followUpWeeks: 4)
        try? await repository.save(glow)

        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) ?? today
        let birthday = Birthday(
            month: calendar.component(.month, from: tomorrow), day: calendar.component(.day, from: tomorrow)
        )
        let people = [
            Client(id: julia, name: "Julia Mendes", phoneE164: "+5511955550001", createdAt: now),
            Client(id: camila, name: "Camila Rocha", phoneE164: "+5511955550002", createdAt: now),
            Client(id: ana, name: "Ana Costa", phoneE164: "+5511955550003", createdAt: now),
            Client(id: beatriz, name: "Beatriz Lima", phoneE164: "+5511955550004", createdAt: now),
            Client(id: larissa, name: "Larissa Souza", birthday: birthday, createdAt: now)
        ]
        for person in people { _ = try? await repository.save(person) }

        // Earlier today, never before midnight.
        let earlier = max(today, now.addingTimeInterval(-3 * 3600))
        func visit(_ id: UUID, _ client: UUID, _ start: Date, _ status: AppointmentStatus) -> Appointment {
            Appointment(
                id: id, clientID: client, serviceID: glow.id, serviceName: glow.name, startsAt: start,
                endsAt: start.addingTimeInterval(TimeInterval(glow.durationMinutes * 60)), status: status,
                createdAt: min(now, start).addingTimeInterval(-86_400)
            )
        }
        let visits = [
            visit(juliaVisit, julia, earlier, .completed),
            visit(camilaVisit, camila, now.addingTimeInterval(30 * 60), .confirmed),
            visit(anaVisit, ana, now.addingTimeInterval(3 * 3600), .booked),
            visit(fixed(0x104), beatriz, calendar.date(byAdding: .day, value: -90, to: now) ?? now, .completed)
        ]
        for item in visits { try? await repository.save(item) }
    }

    private static func fixed(_ number: Int) -> UUID {
        UUID(uuidString: String(format: "A9902200-0000-4000-8000-%012X", number)) ?? UUID()
    }
}
#endif
