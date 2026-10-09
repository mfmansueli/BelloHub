//
//  OpenTimes.swift
//  BelloHub
//

import Foundation

/// The free start times she can offer herself, from `FreeSlotsCalculator`. The professional books her own
/// agenda, so the two limits that protect her from clients (minimum notice and how far ahead a client may book) do
/// not apply here; a time in the past is still never offered.
enum OpenTimes {
    /// What one day looks like to the suggestions.
    struct Request: Sendable {
        var durationMinutes: Int
        var settings: AvailabilitySettings
        var appointments: [Appointment]
        var blocks: [TimeBlock]
        var now: Date
        /// A visit being moved: its own time does not block it.
        var ignoring: UUID?
        var stepMinutes = 15
    }

    /// The free start times of the day containing `day`, in time order.
    static func slots(on day: Date, _ request: Request) -> [Date] {
        var settings = request.settings
        settings.minNoticeHours = 0
        settings.maxDaysAhead = 3_650
        let held = request.appointments.filter {
            $0.id != request.ignoring && $0.status != .cancelled && $0.status != .noShow
        }
        return FreeSlotsCalculator.slots(for: FreeSlotsRequest(
            day: day, durationMinutes: max(request.durationMinutes, 1), now: request.now, settings: settings,
            appointments: held.map(\.interval), blocks: request.blocks.map(\.interval),
            stepMinutes: request.stepMinutes
        ))
    }

    /// The next days (starting with `from`, looking at most `lookahead` days ahead) that have a free start, with
    /// their times, up to `count` days.
    static func nextDays(
        from day: Date, count: Int, lookahead: Int = 45, days: CalendarDays, _ request: Request
    ) -> [(day: Date, slots: [Date])] {
        var found: [(day: Date, slots: [Date])] = []
        for offset in 0..<lookahead where found.count < count {
            let candidate = days.adding(days: offset, to: day)
            let slots = slots(on: candidate, request)
            if !slots.isEmpty { found.append((candidate, slots)) }
        }
        return found
    }

    /// The starts of the visits of `durationMinutes` that fit in the day's free time one after another, each kept
    /// `bufferMinutes` from the next, filled from the earliest time. What the week summary calls "open slots".
    static func fits(on day: Date, _ request: Request) -> [Date] {
        let length = TimeInterval((request.durationMinutes + request.settings.bufferMinutes) * 60)
        var starts: [Date] = []
        var nextFree = Date.distantPast
        for slot in slots(on: day, request) where slot >= nextFree {
            starts.append(slot)
            nextFree = slot.addingTimeInterval(length)
        }
        return starts
    }

    static func fitCount(on day: Date, _ request: Request) -> Int {
        fits(on: day, request).count
    }
}
