//
//  BlockPlanner.swift
//  BelloHub
//

import Foundation

/// Blocking time: which real stretches her choice means, which booked visits fall inside them, and whether the choice
/// is valid. Pure; the business time zone and the daylight-saving rules are `FreeSlotsCalculator`'s.
enum BlockPlanner {
    enum Scope: Hashable, Sendable {
        case wholeDay
        /// Minutes after local midnight, on each chosen day.
        case hours(startMinutes: Int, endMinutes: Int)
    }

    enum Issue: Hashable, Sendable {
        case noDays
        /// "Until" is not after "From".
        case emptyHours
    }

    /// What she does with the visits already booked in a blocked stretch.
    enum VisitChoice: String, CaseIterable, Identifiable, Sendable {
        /// Cancel them as the professional (never counted against the client) and offer to message each client.
        case cancelAndInvite
        /// Leave them as they are for now.
        case keep

        var id: String { rawValue }
    }

    static func issue(days: [Date], scope: Scope) -> Issue? {
        if days.isEmpty { return .noDays }
        if case .hours(let start, let end) = scope, end <= start { return .emptyHours }
        return nil
    }

    /// One block per chosen day, in day order. `makeID` is injected so a test is deterministic.
    static func blocks(
        days: [Date], scope: Scope, reason: String?, settings: AvailabilitySettings, makeID: () -> UUID = { UUID() }
    ) -> [TimeBlock] {
        let trimmed = reason?.trimmingCharacters(in: .whitespacesAndNewlines)
        let note = (trimmed?.isEmpty ?? true) ? nil : trimmed
        return days.sorted().compactMap { day -> TimeBlock? in
            guard let interval = interval(on: day, scope: scope, settings: settings) else { return nil }
            return TimeBlock(id: makeID(), startsAt: interval.start, endsAt: interval.end, reason: note)
        }
    }

    static func interval(on day: Date, scope: Scope, settings: AvailabilitySettings) -> DateInterval? {
        switch scope {
        case .wholeDay:
            return FreeSlotsCalculator.wallInterval(startMinutes: 0, endMinutes: 24 * 60, on: day, settings: settings)
        case .hours(let start, let end):
            return FreeSlotsCalculator.wallInterval(startMinutes: start, endMinutes: end, on: day, settings: settings)
        }
    }

    /// The visits still holding time that overlap any of `blocks`, in time order.
    static func affected(by blocks: [TimeBlock], appointments: [Appointment]) -> [Appointment] {
        appointments.filter { appointment in
            appointment.status.holdsTime && blocks.contains { overlaps($0.interval, appointment.interval) }
        }.sorted { $0.startsAt < $1.startsAt }
    }

    /// How many visits each day has that the block of that day would touch, keyed by the start of the day.
    static func bookedCounts(
        days: [Date], scope: Scope, appointments: [Appointment], settings: AvailabilitySettings
    ) -> [Date: Int] {
        var counts: [Date: Int] = [:]
        for day in days {
            guard let stretch = interval(on: day, scope: scope, settings: settings) else { continue }
            counts[day] = appointments.filter { $0.status.holdsTime && overlaps(stretch, $0.interval) }.count
        }
        return counts
    }

    private static func overlaps(_ first: DateInterval, _ second: DateInterval) -> Bool {
        first.start < second.end && second.start < first.end
    }
}
