//
//  AvailabilityText.swift
//  BelloHub
//

import Foundation

/// The words of the availability screens built from her settings: a day's hours, a break's detail, a day-off range and
/// the one-line week summary of the booking page row. Dates and times come from `Formatters`, so they are the locale's.
struct AvailabilityText {
    let formatters: Formatters
    /// The first day of the week as she draws it (1 is Sunday).
    let firstWeekday: Int

    /// "09:00 – 19:00", or both stretches of a split day joined as a list. Nil when the day is closed.
    func hours(of weekday: Int, in settings: AvailabilitySettings) -> String? {
        let stretches = AvailabilityEditor.stretches(for: weekday, in: settings)
        guard !stretches.isEmpty else { return nil }
        return formatters.list(stretches.map {
            formatters.timeRange(startMinutes: $0.startMinutes, endMinutes: $0.endMinutes)
        })
    }

    /// "12:30 – 13:30 · every day" or "… · Monday".
    func detail(of rule: BreakRule) -> String {
        let when = rule.weekday.map(formatters.weekdayName) ?? String(localized: LocalizedStringResource(
            "availability.break.everyDay", defaultValue: "every day", locale: formatters.locale
        ))
        return "\(formatters.timeRange(startMinutes: rule.startMinutes, endMinutes: rule.endMinutes)) · \(when)"
    }

    /// "Monday, October 12" for one day, "Dec 22 – Jan 5" for several.
    func range(of dayOff: DayOff) -> String {
        formatters.dayRange(from: dayOff.startDate, to: dayOff.endDate)
    }

    /// "Tue to Sat · 09:00 – 19:00": the open days, and the hours when they are the same every day.
    func weekSummary(of settings: AvailabilitySettings) -> String {
        let runs = AvailabilitySummary.openRuns(in: settings, firstWeekday: firstWeekday)
        guard !runs.isEmpty else {
            return String(localized: LocalizedStringResource(
                "availability.summary.none", defaultValue: "No working hours yet", locale: formatters.locale
            ))
        }
        let days = formatters.list(runs.map(describe))
        guard let common = AvailabilitySummary.commonHours(in: settings) else { return days }
        return "\(days) · \(formatters.timeRange(startMinutes: common.start, endMinutes: common.end))"
    }

    // MARK: - Private

    /// A run of three or more days reads "Tue to Sat"; one or two are named ("Tue and Wed").
    private func describe(_ run: [Int]) -> String {
        guard run.count >= 3, let first = run.first, let last = run.last else {
            return formatters.list(run.map(formatters.weekdayShortName))
        }
        let from = formatters.weekdayShortName(first)
        let to = formatters.weekdayShortName(last)
        return String(localized: LocalizedStringResource(
            "availability.summary.days", defaultValue: "\(from) to \(to)", locale: formatters.locale
        ))
    }
}
