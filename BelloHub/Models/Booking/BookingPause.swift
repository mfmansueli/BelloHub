//
//  BookingPause.swift
//  BelloHub
//

import Foundation

/// The pause rules of the booking page (D15), pure so the settings screen, the More row and the publisher agree.
///
/// A pause with a return date ends **on the morning of that date** in the business time zone: "back on Oct 20" means
/// October 20 is bookable again. A pause without one lasts until she opens bookings again.
enum BookingPause {
    /// Where the page stands at `now`. A pause whose return day has come counts as open even if nobody has saved that.
    static func state(of settings: BookingPageSettings, now: Date, timeZone: TimeZone) -> BookingPageState {
        guard !settings.acceptingBookings else { return .accepting }
        guard let until = settings.pausedUntil else { return .paused(until: nil) }
        let returnDay = startOfDay(until, timeZone: timeZone)
        return now >= returnDay ? .accepting : .paused(until: returnDay)
    }

    /// The first day she can choose to come back: tomorrow, because a pause that ends today is no pause.
    static func earliestReturnDate(now: Date, timeZone: TimeZone) -> Date {
        let calendar = calendar(in: timeZone)
        let today = calendar.startOfDay(for: now)
        return calendar.date(byAdding: .day, value: 1, to: today) ?? today
    }

    /// The settings with bookings paused. A return date before the earliest possible one is dropped rather than
    /// guessed, so a stale date picker can never save a pause that is already over.
    static func pausing(
        _ settings: BookingPageSettings, until: Date?, now: Date, timeZone: TimeZone
    ) -> BookingPageSettings {
        var paused = settings
        paused.acceptingBookings = false
        let earliest = earliestReturnDate(now: now, timeZone: timeZone)
        if let until, startOfDay(until, timeZone: timeZone) >= earliest {
            paused.pausedUntil = startOfDay(until, timeZone: timeZone)
        } else {
            paused.pausedUntil = nil
        }
        return paused
    }

    /// The settings with bookings open again and no return date.
    static func resuming(_ settings: BookingPageSettings) -> BookingPageSettings {
        var open = settings
        open.acceptingBookings = true
        open.pausedUntil = nil
        return open
    }

    /// What gets saved: an expired pause becomes an open page, so storage never says "paused until last month".
    static func normalized(_ settings: BookingPageSettings, now: Date, timeZone: TimeZone) -> BookingPageSettings {
        let expired = !settings.acceptingBookings && state(of: settings, now: now, timeZone: timeZone) == .accepting
        return expired ? resuming(settings) : settings
    }

    // MARK: - Private

    private static func calendar(in timeZone: TimeZone) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }

    private static func startOfDay(_ date: Date, timeZone: TimeZone) -> Date {
        calendar(in: timeZone).startOfDay(for: date)
    }
}
