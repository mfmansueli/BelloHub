//
//  Formatters+Visit.swift
//  BelloHub
//

import Foundation

extension Formatters {
    /// "3:00 to 4:30 PM" in the locale's own words and clock, in the business time zone.
    func timeSpan(from start: Date, to end: Date) -> String {
        guard end > start else { return time(start) }
        return (start..<end).formatted(Date.IntervalFormatStyle(
            date: .omitted, time: .shortened, locale: locale, calendar: calendar, timeZone: timeZone
        ))
    }

    /// `today`, `tomorrow`, or "Wed, Sep 30": the day of a visit in few characters.
    func visitDay(_ date: Date, now: Date, today: String, tomorrow: String) -> String {
        let startOfToday = calendar.startOfDay(for: now)
        let days = calendar.dateComponents([.day], from: startOfToday, to: calendar.startOfDay(for: date)).day ?? 99
        switch days {
        case 0: return today
        case 1: return tomorrow
        default:
            return date.formatted(Date.FormatStyle(locale: locale, calendar: calendar, timeZone: timeZone)
                .weekday(.abbreviated).month(.abbreviated).day())
        }
    }

    /// "Today · 3:00 to 4:30 PM": when a visit is.
    func visitWhen(_ appointment: Appointment, now: Date, today: String, tomorrow: String) -> String {
        let day = visitDay(appointment.startsAt, now: now, today: today, tomorrow: tomorrow)
        return "\(day) · \(timeSpan(from: appointment.startsAt, to: appointment.endsAt))"
    }
}
