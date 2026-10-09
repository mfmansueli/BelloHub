//
//  CalendarUITestSeeding.swift
//  BelloHub
//

#if DEBUG
import Foundation

/// What `-uiCalendar` adds before the app starts: a working week of every day from 09:00 to 18:00 with no breaks, so
/// whatever day and hour a UI test runs there is a free hour to tap and a day with free times to move a visit to.
/// `-uiCalendarVisits` adds two clients, three visits (two of them overlapping, to draw columns) and a block, relative
/// to today, so the audit walks a calendar with something in it.
/// It goes straight to the vault and does not depend on `-uiSeed` (which brings the clients and the services of the
/// workspace). DEBUG only.
enum CalendarUITestSeeding {
    static let argument = "-uiCalendar"
    static let visitsArgument = "-uiCalendarVisits"
    static let timeZoneID = "America/Sao_Paulo"

    @MainActor
    static func seedIfRequested(
        _ dependencies: AppDependencies, arguments: [String] = ProcessInfo.processInfo.arguments
    ) async {
        guard arguments.contains(argument), let repository = dependencies.vault.repository else { return }
        let week = AvailabilitySettings(
            weekly: (1...7).map { AvailabilityRule(weekday: $0, startMinutes: 9 * 60, endMinutes: 18 * 60) },
            breaks: [], daysOff: [], bufferMinutes: 0, minNoticeHours: 0, maxDaysAhead: 90, timeZoneID: timeZoneID
        )
        try? await repository.save(week)
        guard arguments.contains(visitsArgument) else { return }
        await seedVisits(into: repository, settings: week, now: Date())
    }

    private static func seedVisits(
        into repository: any ClientRecordRepository, settings: AvailabilitySettings, now: Date
    ) async {
        let days = CalendarDays(timeZone: settings.timeZone)
        let today = days.start(of: now)
        let camila = Client(name: "Camila Rocha", phoneE164: "+5511955550003", createdAt: now)
        let julia = Client(name: "Julia Mendes", createdAt: now)
        _ = try? await repository.save(camila)
        _ = try? await repository.save(julia)
        struct Entry {
            let client: Client
            let dayOffset: Int
            let minutes: Int
            let length: Int
            let status: AppointmentStatus
            let service: String
        }
        let entries = [
            Entry(client: camila, dayOffset: 0, minutes: 10 * 60, length: 60, status: .confirmed,
                  service: "Glow Facial"),
            Entry(client: julia, dayOffset: 0, minutes: 10 * 60 + 30, length: 75, status: .booked,
                  service: "Deep Cleansing"),
            Entry(client: camila, dayOffset: 1, minutes: 11 * 60, length: 60, status: .booked, service: "Glow Facial")
        ]
        for entry in entries {
            let start = days.date(on: days.adding(days: entry.dayOffset, to: today), minutes: entry.minutes)
            let visit = Appointment(
                clientID: entry.client.id, serviceName: entry.service, startsAt: start,
                endsAt: start.addingTimeInterval(TimeInterval(entry.length * 60)), status: entry.status, createdAt: now
            )
            try? await repository.save(visit)
        }
        let blockStart = days.date(on: days.adding(days: 2, to: today), minutes: 14 * 60)
        try? await repository.save(TimeBlock(
            id: UUID(), startsAt: blockStart, endsAt: blockStart.addingTimeInterval(7_200), reason: "Course"
        ))
    }
}
#endif
