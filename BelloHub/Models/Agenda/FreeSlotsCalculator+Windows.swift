//
//  FreeSlotsCalculator+Windows.swift
//  BelloHub
//

import Foundation

/// The pieces of a day that `FreeSlotsCalculator` is built from, for the screens that draw or check a day (the
/// calendar's bands, the warnings of a new visit). They share the calculator's wall-clock-to-instant rules, so a
/// working stretch or a break is the same real interval everywhere, also on a daylight-saving change day.
extension FreeSlotsCalculator {
    /// The day off that covers `dayStart` (the start of a day in the business time zone), if any.
    static func dayOff(on dayStart: Date, settings: AvailabilitySettings, calendar: Calendar) -> DayOff? {
        settings.daysOff.first { off in
            let first = calendar.startOfDay(for: off.startDate)
            let final = calendar.startOfDay(for: off.endDate)
            return dayStart >= first && dayStart <= final
        }
    }

    /// Her working stretches of the day containing `date`, in time order. Empty on a day off and on a day she does
    /// not work.
    static func workingWindows(on date: Date, settings: AvailabilitySettings) -> [DateInterval] {
        let calendar = businessCalendar(settings)
        let dayStart = calendar.startOfDay(for: date)
        guard let nextDayStart = calendar.date(byAdding: .day, value: 1, to: dayStart),
              dayOff(on: dayStart, settings: settings, calendar: calendar) == nil else { return [] }
        let weekday = calendar.component(.weekday, from: dayStart)
        return settings.weekly.filter { $0.weekday == weekday }
            .compactMap { interval(startMinutes: $0.startMinutes, endMinutes: $0.endMinutes, dayStart: dayStart,
                                   nextDayStart: nextDayStart, calendar: calendar) }
            .sorted { $0.start < $1.start }
    }

    /// Her breaks of the day containing `date`, with their labels, in time order.
    static func breakWindows(
        on date: Date, settings: AvailabilitySettings
    ) -> [(label: String, interval: DateInterval)] {
        let calendar = businessCalendar(settings)
        let dayStart = calendar.startOfDay(for: date)
        guard let nextDayStart = calendar.date(byAdding: .day, value: 1, to: dayStart) else { return [] }
        let weekday = calendar.component(.weekday, from: dayStart)
        return settings.breaks.filter { $0.weekday == nil || $0.weekday == weekday }
            .compactMap { rule in
                interval(startMinutes: rule.startMinutes, endMinutes: rule.endMinutes, dayStart: dayStart,
                         nextDayStart: nextDayStart, calendar: calendar).map { (rule.label, $0) }
            }
            .sorted { $0.interval.start < $1.interval.start }
    }

    /// The real interval of a wall-clock stretch of the day containing `date` (minutes after local midnight).
    static func wallInterval(
        startMinutes: Int, endMinutes: Int, on date: Date, settings: AvailabilitySettings
    ) -> DateInterval? {
        let calendar = businessCalendar(settings)
        let dayStart = calendar.startOfDay(for: date)
        guard let nextDayStart = calendar.date(byAdding: .day, value: 1, to: dayStart) else { return nil }
        return interval(startMinutes: startMinutes, endMinutes: endMinutes, dayStart: dayStart,
                        nextDayStart: nextDayStart, calendar: calendar)
    }

    private static func businessCalendar(_ settings: AvailabilitySettings) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = settings.timeZone
        return calendar
    }
}
