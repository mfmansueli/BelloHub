//
//  WeekSummary.swift
//  BelloHub
//

import Foundation

/// The numbers of the "This week" screen: visits left today, open slots, and for each working day how many visits are
/// booked of how many fit. Pure; `now` and the days come in.
struct WeekSummary: Equatable, Sendable {
    /// One day of the week she works (or has visits on).
    struct DayRow: Equatable, Identifiable, Sendable {
        /// The start of the day in the business time zone.
        let day: Date
        let booked: Int
        /// Visits booked plus the visits that still fit in the free time.
        let capacity: Int
        let isToday: Bool

        var id: Date { day }
        var fraction: Double { capacity > 0 ? Double(booked) / Double(capacity) : 0 }
    }

    /// A free stretch worth showing as a suggestion.
    struct OpenSlot: Equatable, Identifiable, Sendable {
        let start: Date
        var id: Date { start }
    }

    let weekStart: Date
    let rows: [DayRow]
    /// Visits today that have not started or ended yet and still hold time.
    let leftToday: Int
    let openSlotCount: Int
    /// The first visits that fit in the free time of the week from now on, at most `maximumSuggestions`.
    let suggestions: [OpenSlot]

    static let maximumSuggestions = 5

    struct Input: Sendable {
        var now: Date
        var settings: AvailabilitySettings
        var appointments: [Appointment]
        var blocks: [TimeBlock]
        /// The shortest active service: an "open slot" is room for one of those.
        var shortestServiceMinutes: Int
    }

    static func make(_ input: Input, days: CalendarDays) -> WeekSummary {
        var input = input
        // Her hours are read in the zone the days are cut in, whatever zone they were saved in.
        input.settings = input.settings.inTimeZone(days.calendar.timeZone)
        let week = days.week(containing: input.now)
        let held = input.appointments.filter { $0.status.holdsTime || $0.status == .completed }
        let duration = max(input.shortestServiceMinutes, 15)
        let request = OpenTimes.Request(
            durationMinutes: duration, settings: input.settings, appointments: input.appointments,
            blocks: input.blocks, now: input.now, stepMinutes: 15
        )
        var rows: [DayRow] = []
        var openTotal = 0
        var suggestions: [OpenSlot] = []
        for day in week {
            let interval = days.interval(of: day)
            let booked = held.filter { $0.interval.intersection(with: interval) != nil }.count
            let fits = OpenTimes.fits(on: day, request)
            let open = fits.count
            openTotal += open
            if suggestions.count < maximumSuggestions {
                suggestions += fits.prefix(maximumSuggestions - suggestions.count).map(OpenSlot.init)
            }
            let works = !FreeSlotsCalculator.workingWindows(on: day, settings: input.settings).isEmpty
            guard works || booked > 0 else { continue }
            rows.append(DayRow(day: day, booked: booked, capacity: booked + open,
                               isToday: days.isSameDay(day, input.now)))
        }
        let today = days.interval(of: input.now)
        let left = input.appointments.filter {
            $0.status.holdsTime && $0.endsAt > input.now && $0.interval.intersection(with: today) != nil
        }.count
        return WeekSummary(weekStart: week.first ?? input.now, rows: rows, leftToday: left,
                           openSlotCount: openTotal, suggestions: suggestions)
    }
}
