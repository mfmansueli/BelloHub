//
//  FreeSlotsCalculator.swift
//  BelloHub
//

import Foundation

/// The free start times of a day: availability minus visits, breaks, days off, blocks and the buffer, in the
/// **business** time zone, correct on daylight-saving change days (docs/05-DATA-MODEL.md, "FreeSlots").
/// The same table tests are run against the server's `functions/src/lib/rules.ts` so the two cannot drift.
enum FreeSlotsCalculator {
    static func slots(for request: FreeSlotsRequest) -> [Date] {
        let settings = request.settings
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = settings.timeZone
        let dayStart = calendar.startOfDay(for: request.day)
        guard let nextDayStart = calendar.date(byAdding: .day, value: 1, to: dayStart),
              isBookableDay(dayStart, request: request, calendar: calendar) else { return [] }

        let weekday = calendar.component(.weekday, from: dayStart)
        let breaks = settings.breaks
            .filter { $0.weekday == nil || $0.weekday == weekday }
            .compactMap { interval(startMinutes: $0.startMinutes, endMinutes: $0.endMinutes, dayStart: dayStart,
                                   nextDayStart: nextDayStart, calendar: calendar) }
        let buffer = TimeInterval(settings.bufferMinutes * 60)
        let earliest = request.now.addingTimeInterval(TimeInterval(settings.minNoticeHours * 3600))
        let duration = TimeInterval(request.durationMinutes * 60)
        let step = TimeInterval(max(request.stepMinutes, 1) * 60)

        var starts: Set<Date> = []
        for rule in settings.weekly where rule.weekday == weekday {
            guard let window = interval(startMinutes: rule.startMinutes, endMinutes: rule.endMinutes,
                                        dayStart: dayStart, nextDayStart: nextDayStart, calendar: calendar) else {
                continue
            }
            var start = window.start
            while start.addingTimeInterval(duration) <= window.end {
                let candidate = DateInterval(start: start, duration: duration)
                if start >= earliest, fits(candidate, breaks: breaks, appointments: request.appointments,
                                           blocks: request.blocks, buffer: buffer) {
                    starts.insert(start)
                }
                start = start.addingTimeInterval(step)
            }
        }
        return starts.sorted()
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

    private static func fits(_ candidate: DateInterval, breaks: [DateInterval], appointments: [DateInterval],
                             blocks: [DateInterval], buffer: TimeInterval) -> Bool {
        let blocked = breaks + blocks
        if blocked.contains(where: { overlaps(candidate, $0, margin: 0) }) { return false }
        return !appointments.contains { overlaps(candidate, $0, margin: buffer) }
    }

    /// Two stretches overlap if the gap between them is smaller than `margin`.
    private static func overlaps(_ first: DateInterval, _ second: DateInterval, margin: TimeInterval) -> Bool {
        first.start < second.end.addingTimeInterval(margin) && first.end.addingTimeInterval(margin) > second.start
    }
}
