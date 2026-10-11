//
//  WeekGlanceViewModel.swift
//  BelloHub
//

import Foundation
import Observation

/// State of the "This week" screen (2.6): the numbers `WeekSummary` computes for the week of today, and how many
/// clients have not been back (`FollowUpPlanner`, the one owner of that rule). It reads once and again on refresh.
@MainActor
@Observable
final class WeekGlanceViewModel {
    private(set) var summary: WeekSummary?
    private(set) var notReturnedCount = 0
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    let days: CalendarDays
    private let appointments: AppointmentService
    private let timeBlocks: TimeBlockService
    private let bookingSetup: BookingSetupService
    private let vault: VaultService
    private let timeZoneID: String
    private let now: @Sendable () -> Date

    init(
        timeZoneID: String, firstWeekday: Int = 2,
        appointments: AppointmentService, timeBlocks: TimeBlockService, bookingSetup: BookingSetupService,
        vault: VaultService, now: @escaping @Sendable () -> Date = { Date() }
    ) {
        days = CalendarDays(timeZone: TimeZone(identifier: timeZoneID) ?? .current, firstWeekday: firstWeekday)
        self.timeZoneID = timeZoneID
        self.appointments = appointments
        self.timeBlocks = timeBlocks
        self.bookingSetup = bookingSetup
        self.vault = vault
        self.now = now
    }

    var weekInterval: DateInterval { days.weekInterval(containing: now()) }

    /// The visits of the shown week were read at least once.
    var hasLoaded: Bool { summary != nil }

    func load() {
        Task { await loadAsync() }
    }

    func loadAsync() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            try await bookingSetup.load(timeZoneID: timeZoneID)
            let week = days.weekInterval(containing: now())
            let visits = try await appointments.appointments(in: week)
            let blocks = try await timeBlocks.blocks(in: week)
            var shortest = 60
            var everyone: [Appointment] = []
            var clients: [Client] = []
            if let repository = vault.repository {
                shortest = try await repository.services().filter(\.isActive).map(\.durationMinutes).min() ?? 60
                clients = try await repository.allClients()
                let history = DateInterval(
                    start: Date(timeIntervalSince1970: 0), end: week.end.addingTimeInterval(31_536_000)
                )
                everyone = try await appointments.appointments(in: history)
            }
            summary = WeekSummary.make(
                WeekSummary.Input(
                    now: now(), settings: bookingSetup.availability.inTimeZone(days.calendar.timeZone),
                    appointments: visits, blocks: blocks,
                    shortestServiceMinutes: shortest
                ),
                days: days
            )
            notReturnedCount = FollowUpPlanner.winBack(
                clients: clients, appointments: everyone, now: now(), calendar: days.calendar
            ).count
        } catch {
            errorMessage = String(interface: LocalizedStringResource(
                "weekGlance.error.load",
                defaultValue: "We could not read your week. Check that your iPhone is unlocked and try again."
            ))
        }
    }
}
