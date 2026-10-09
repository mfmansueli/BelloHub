//
//  CalendarUITestSeeding.swift
//  BelloHub
//

#if DEBUG
import Foundation

/// What `-uiCalendar` adds before the app starts: a working week of every day from 09:00 to 18:00 with no breaks, so
/// whatever day and hour a UI test runs there is a free hour to tap and a day with free times to move a visit to.
/// It goes straight to the vault and does not depend on `-uiSeed` (which brings the clients and the services).
/// DEBUG only.
enum CalendarUITestSeeding {
    static let argument = "-uiCalendar"

    @MainActor
    static func seedIfRequested(
        _ dependencies: AppDependencies, arguments: [String] = ProcessInfo.processInfo.arguments
    ) async {
        guard arguments.contains(argument), let repository = dependencies.vault.repository else { return }
        let week = AvailabilitySettings(
            weekly: (1...7).map { AvailabilityRule(weekday: $0, startMinutes: 9 * 60, endMinutes: 18 * 60) },
            breaks: [], daysOff: [], bufferMinutes: 15, minNoticeHours: 0, maxDaysAhead: 90,
            timeZoneID: "America/Sao_Paulo"
        )
        try? await repository.save(week)
    }
}
#endif
