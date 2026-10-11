//
//  FreeSlotsCalculator.swift
//  BelloHub
//

import Foundation

/// The free start times of a day: availability minus visits, breaks, days off, blocks and the buffer, in the
/// **business** time zone, correct on daylight-saving change days (docs/05-DATA-MODEL.md, "FreeSlots"), with the
/// smart slots of D56: starts anchored against every visit, break, block and stretch edge, the extra and processing
/// time of each visit, and the compact-day ranking.
/// `functions/src/lib/freeSlots.ts` mirrors it line by line; the shared fixture generated from this code
/// (firebase/scripts/rules-fixtures) fails a server test when the two drift.
enum FreeSlotsCalculator {
    /// Anchored starts are rounded inwards to this clock, so a client never sees 10:17.
    static let anchorRoundingMinutes = 5

    static func slots(for request: FreeSlotsRequest) -> [Date] {
        plan(for: request).all
    }

    static func plan(for request: FreeSlotsRequest) -> FreeSlotsPlan {
        let settings = request.settings
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = settings.timeZone
        let dayStart = calendar.startOfDay(for: request.day)
        guard let nextDayStart = calendar.date(byAdding: .day, value: 1, to: dayStart),
              isBookableDay(dayStart, request: request, calendar: calendar) else { return .empty }

        let weekday = calendar.component(.weekday, from: dayStart)
        let breaks = settings.breaks
            .filter { $0.weekday == nil || $0.weekday == weekday }
            .compactMap { interval(startMinutes: $0.startMinutes, endMinutes: $0.endMinutes, dayStart: dayStart,
                                   nextDayStart: nextDayStart, calendar: calendar) }
        let day = Day(request: request, breaks: breaks)

        var all: Set<Date> = []
        var recommended: Set<Date> = []
        for rule in settings.weekly where rule.weekday == weekday {
            guard let window = interval(startMinutes: rule.startMinutes, endMinutes: rule.endMinutes,
                                        dayStart: dayStart, nextDayStart: nextDayStart, calendar: calendar) else {
                continue
            }
            let placements = day.placements(in: window)
            all.formUnion(placements.map(\.start))
            recommended.formUnion(day.isRanked ? compactStarts(placements) : placements.map(\.start))
        }
        return FreeSlotsPlan(all: all.sorted(), recommended: recommended.sorted())
    }

    // MARK: - Private

    private static func isBookableDay(_ dayStart: Date, request: FreeSlotsRequest, calendar: Calendar) -> Bool {
        let today = calendar.startOfDay(for: request.now)
        guard let last = calendar.date(byAdding: .day, value: request.settings.maxDaysAhead, to: today),
              dayStart >= today, dayStart <= last else { return false }
        return dayOff(on: dayStart, settings: request.settings, calendar: calendar) == nil
    }

    /// The real-time interval of a local wall-clock stretch. A time that does not exist (spring forward) moves to
    /// the next valid one; a time that happens twice (fall back) means its first occurrence. Midnight at the end of
    /// the day is the start of the next day.
    static func interval(startMinutes: Int, endMinutes: Int, dayStart: Date, nextDayStart: Date,
                         calendar: Calendar) -> DateInterval? {
        func resolve(_ minutes: Int) -> Date? {
            instant(minutes: minutes, dayStart: dayStart, nextDayStart: nextDayStart, calendar: calendar)
        }
        guard let start = resolve(startMinutes), let end = resolve(endMinutes), end > start else { return nil }
        return DateInterval(start: start, end: end)
    }

    static func instant(minutes: Int, dayStart: Date, nextDayStart: Date, calendar: Calendar) -> Date? {
        if minutes >= 24 * 60 { return nextDayStart }
        return calendar.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: dayStart,
                             matchingPolicy: .nextTime, repeatedTimePolicy: .first, direction: .forward)
    }
}
