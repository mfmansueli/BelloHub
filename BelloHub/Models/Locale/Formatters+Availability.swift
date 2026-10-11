//
//  Formatters+Availability.swift
//  BelloHub
//

import Foundation

/// Times of day, weekday names and day ranges for the availability screens. Like everything else in `Formatters`, they
/// follow the reader's locale in the **business** time zone.
extension Formatters {
    /// An instant for `minutes` after midnight on a plain winter day in the business zone, for formatting and for date
    /// pickers that edit a time of day. A day with no daylight-saving change, so the minutes are never shifted.
    func timeOfDay(minutes: Int) -> Date {
        let reference = DateComponents(year: 2001, month: 1, day: 15)
        let midnight = calendar.date(from: reference) ?? Date(timeIntervalSince1970: 0)
        return calendar.date(byAdding: .minute, value: minutes, to: midnight) ?? midnight
    }

    /// The minutes after midnight of an instant, read in the business zone: the inverse of `timeOfDay(minutes:)`.
    func minutesOfDay(_ date: Date) -> Int {
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        return (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
    }

    /// "09:00" or "9:00 AM": a time of day from minutes after midnight.
    func time(minutes: Int, use24Hour: Bool? = nil) -> String {
        time(timeOfDay(minutes: minutes), use24Hour: use24Hour)
    }

    /// "09:00 – 19:00" or "9:00 AM – 7:00 PM": the locale's own way to write a stretch of the day.
    func timeRange(startMinutes: Int, endMinutes: Int) -> String {
        let style = Date.IntervalFormatStyle(locale: locale, calendar: calendar, timeZone: timeZone).hour().minute()
        return (timeOfDay(minutes: startMinutes)..<timeOfDay(minutes: endMinutes)).formatted(style)
    }

    /// "Tuesday": the full weekday name (1 is Sunday, as in `Calendar`).
    func weekdayName(_ weekday: Int) -> String {
        symbol(in: calendar.standaloneWeekdaySymbols, weekday)
    }

    /// "Tue": the short weekday name.
    func weekdayShortName(_ weekday: Int) -> String {
        symbol(in: calendar.shortStandaloneWeekdaySymbols, weekday)
    }

    /// "Oct 12": a day without the year, for a list of days off.
    func dayMonth(_ date: Date) -> String {
        date.formatted(Date.FormatStyle(locale: locale, calendar: calendar, timeZone: timeZone)
            .month(.abbreviated).day())
    }

    /// "Dec 22 – Jan 5", or a single day when both ends are the same day.
    func dayRange(from start: Date, to end: Date) -> String {
        guard calendar.startOfDay(for: start) != calendar.startOfDay(for: end) else { return weekdayDayMonth(start) }
        let style = Date.IntervalFormatStyle(locale: locale, calendar: calendar, timeZone: timeZone)
            .month(.abbreviated).day()
        return (start..<end).formatted(style)
    }

    /// "24 h": a number of hours, abbreviated.
    func hours(_ value: Int) -> String {
        Duration.seconds(value * 3_600).formatted(
            Duration.UnitsFormatStyle(allowedUnits: [.hours], width: .abbreviated).locale(locale)
        )
    }

    private func symbol(in symbols: [String], _ weekday: Int) -> String {
        symbols.indices.contains(weekday - 1) ? symbols[weekday - 1] : ""
    }
}
