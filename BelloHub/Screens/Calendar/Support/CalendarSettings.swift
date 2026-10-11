//
//  CalendarSettings.swift
//  BelloHub
//

import Foundation

/// The profile's choices the calendar screens need, read in one place: the business time zone (never the phone's),
/// the first day of the week she works with, and the formatters for dates and times.
///
/// A screen builds its ViewModel from these and keeps it in `@State`, so the ViewModel keeps the values of the first
/// frame. Before her profile is read they are only the phone's zone and a Monday week; a screen built then cut its days
/// at the phone's midnight while its labels, rebuilt with the profile, were written in the business zone: with the
/// phone ahead of the business every visit showed under the day before (fix-reschedule-day). So every screen that
/// builds a ViewModel from these is identified by them (`.id(settings)`), and is built again when they change.
struct CalendarSettings: Hashable, Sendable {
    let timeZoneID: String
    let firstWeekday: Int
    let currencyCode: String

    init(profile: ProfessionalProfile?, fallbackTimeZoneID: String = TimeZone.current.identifier) {
        timeZoneID = profile?.timeZoneID ?? fallbackTimeZoneID
        firstWeekday = profile?.weekConfig.firstWeekday ?? 2
        currencyCode = profile?.currencyCode ?? "EUR"
    }

    var timeZone: TimeZone { TimeZone(identifier: timeZoneID) ?? .current }

    func formatters(locale: Locale) -> Formatters {
        Formatters(locale: locale, timeZone: timeZone, currencyCode: currencyCode, firstWeekday: firstWeekday)
    }
}
