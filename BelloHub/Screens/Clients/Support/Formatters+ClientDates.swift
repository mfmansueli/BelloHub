//
//  Formatters+ClientDates.swift
//  BelloHub
//

import Foundation

extension Formatters {
    /// "Aug 30" for a date in the same year as `now`, "Aug 30, 2025" for any other: a list row says when she was last
    /// seen, and the year only matters once it is not this one. In the business time zone, in the reader's locale.
    func recentDate(_ date: Date, now: Date) -> String {
        guard calendar.component(.year, from: date) == calendar.component(.year, from: now) else {
            return shortDate(date)
        }
        return date.formatted(Date.FormatStyle(locale: locale, calendar: calendar, timeZone: timeZone)
            .month(.abbreviated).day())
    }

    /// "Today · 15:00", "Tomorrow · 09:30" or "Oct 1 · 15:00": when an appointment is, for the profile's "Next" tile.
    func dayAndTime(_ date: Date, now: Date, today: String, tomorrow: String) -> String {
        let startOfToday = calendar.startOfDay(for: now)
        let days = calendar.dateComponents([.day], from: startOfToday, to: calendar.startOfDay(for: date)).day ?? 99
        let day: String
        switch days {
        case 0: day = today
        case 1: day = tomorrow
        default: day = recentDate(date, now: now)
        }
        return "\(day) · \(time(date))"
    }
}
