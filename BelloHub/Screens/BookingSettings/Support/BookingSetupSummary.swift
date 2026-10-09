//
//  BookingSetupSummary.swift
//  BelloHub
//

import Foundation

/// The one-line summaries under the rows of the booking screens ("Free up to 24 h", "On · limit 3", "Paused until Oct
/// 20"). One owner, so the booking page settings, the cancel policy, the no-show policy and More say the same thing.
enum BookingSetupSummary {
    /// "Free up to 24 h".
    static func cancellation(_ policy: CancellationPolicy, formatters: Formatters) -> LocalizedStringResource {
        let window = formatters.hours(policy.freeWindowHours)
        return LocalizedStringResource(
            "bookingSettings.cancel.summary", defaultValue: "Free up to \(window)", locale: formatters.locale
        )
    }

    /// "On · limit 3" or "Off".
    static func noShow(_ policy: NoShowPolicy) -> LocalizedStringResource {
        guard policy.isOn else {
            return LocalizedStringResource("bookingSettings.noShow.off", defaultValue: "Off")
        }
        return LocalizedStringResource("bookingSettings.noShow.on", defaultValue: "On · limit \(policy.limit)")
    }

    /// The More row of the booking page: whether it takes bookings, and until when it is paused.
    static func page(_ settings: BookingPageSettings, now: Date, timeZone: TimeZone, formatters: Formatters)
        -> LocalizedStringResource {
        switch BookingPause.state(of: settings, now: now, timeZone: timeZone) {
        case .accepting:
            return LocalizedStringResource("more.row.bookingPage.taking", defaultValue: "Taking bookings")
        case .paused(let until?):
            let date = formatters.dayMonth(until)
            return LocalizedStringResource("more.row.bookingPage.pausedUntil", defaultValue: "Paused until \(date)")
        case .paused(nil):
            return LocalizedStringResource("more.row.bookingPage.paused", defaultValue: "Paused")
        }
    }
}
