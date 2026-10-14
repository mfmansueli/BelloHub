//
//  OpenTimes.swift
//  BelloHub
//

import Foundation

/// The free start times she can offer herself, from `FreeSlotsCalculator`, with the same smart slots as her booking
/// page (D56): her slot interval, the extra and processing time of every visit, and "Keep my day compact". The
/// professional books her own agenda, so the two limits that protect her from clients (minimum notice and how far
/// ahead a client may book) do not apply here; a time in the past is still never offered.
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
        /// The grid of start times; nil is her slot interval from Booking settings.
        var stepMinutes: Int?
        /// Her services: the extra and processing time of each visit, and her shortest offer.
        var services: [Service] = []
        /// The new visit's extra and processing time.
        var timing = VisitTiming.noExtraTime
    }

    /// Every free start time of the day containing `day`, in time order.
    static func slots(on day: Date, _ request: Request) -> [Date] {
        plan(on: day, request).all
    }

    /// The free starts of the day containing `day`, and the ones to suggest first.
    static func plan(on day: Date, _ request: Request) -> FreeSlotsPlan {
        var settings = request.settings
        settings.minNoticeHours = 0
        settings.maxDaysAhead = 3_650
        let timings = Dictionary(request.services.map { ($0.id, $0.visitTiming) }) { first, _ in first }
        let held = request.appointments.filter {
            $0.id != request.ignoring && $0.status != .cancelled && $0.status != .noShow
        }
        let visits = held.map {
            TimedInterval($0.interval, timing: $0.serviceTiming ?? $0.serviceID.flatMap { timings[$0] }
                ?? .noExtraTime)
        }
        return FreeSlotsCalculator.plan(for: FreeSlotsRequest(
            day: day, durationMinutes: max(request.durationMinutes, 1), now: request.now, settings: settings,
            appointments: visits, blocks: request.blocks.map(\.interval),
            stepMinutes: request.stepMinutes ?? settings.effectiveSlotStep, timing: request.timing,
            compact: settings.keepsDayCompact,
            shortestOfferMinutes: AvailabilitySettings.shortestOfferMinutes(of: request.services)
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
