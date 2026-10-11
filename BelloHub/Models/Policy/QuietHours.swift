//
//  QuietHours.swift
//  BelloHub
//

import Foundation

/// Quiet hours hold non-urgent alerts at night. A client running late and a same-day cancellation always come through.
enum QuietHours {
    static func isQuiet(at date: Date, window: QuietHoursWindow?, calendar: Calendar) -> Bool {
        guard let window, window.fromMinutes != window.untilMinutes else { return false }
        let minutes = minutesSinceMidnight(date, calendar: calendar)
        if window.fromMinutes < window.untilMinutes {
            return minutes >= window.fromMinutes && minutes < window.untilMinutes
        }
        // Overnight (22:00 to 07:00): quiet from the start until midnight and from midnight until the end.
        return minutes >= window.fromMinutes || minutes < window.untilMinutes
    }

    /// Urgent alerts: a client running late, and a cancellation of a visit that is today.
    static func isUrgent(kind: AlertKind, visitStartsAt: Date?, now: Date, calendar: Calendar) -> Bool {
        switch kind {
        case .clientRunningLate:
            return true
        case .cancellation:
            return visitStartsAt.map { calendar.isDate($0, inSameDayAs: now) } ?? false
        default:
            return false
        }
    }

    static func shouldDeliverNow(
        kind: AlertKind, visitStartsAt: Date? = nil, at now: Date, window: QuietHoursWindow?, calendar: Calendar
    ) -> Bool {
        isUrgent(kind: kind, visitStartsAt: visitStartsAt, now: now, calendar: calendar)
            || !isQuiet(at: now, window: window, calendar: calendar)
    }

    /// When held alerts are released: the next time the quiet window ends, or nil when it is not quiet.
    static func nextRelease(after date: Date, window: QuietHoursWindow?, calendar: Calendar) -> Date? {
        guard let window, isQuiet(at: date, window: window, calendar: calendar) else { return nil }
        let components = DateComponents(hour: window.untilMinutes / 60, minute: window.untilMinutes % 60)
        return calendar.nextDate(after: date, matching: components, matchingPolicy: .nextTime)
    }

    private static func minutesSinceMidnight(_ date: Date, calendar: Calendar) -> Int {
        calendar.component(.hour, from: date) * 60 + calendar.component(.minute, from: date)
    }
}
