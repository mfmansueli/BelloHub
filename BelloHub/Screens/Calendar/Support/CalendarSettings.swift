//
//  CalendarSettings.swift
//  BelloHub
//

import Foundation

/// The profile's choices the calendar screens need, read in one place: the business time zone (never the phone's),
/// the first day of the week of her region, and the formatters for dates and times.
struct CalendarSettings: Hashable, Sendable {
    let timeZoneID: String
    let firstWeekday: Int
    let currencyCode: String

    init(profile: ProfessionalProfile?, fallbackTimeZoneID: String = TimeZone.current.identifier) {
        timeZoneID = profile?.timeZoneID ?? fallbackTimeZoneID
        firstWeekday = profile.map { WeekConfig.defaults(forRegion: $0.regionCode).firstWeekday } ?? 2
        currencyCode = profile?.currencyCode ?? "EUR"
    }

    var timeZone: TimeZone { TimeZone(identifier: timeZoneID) ?? .current }

    func formatters(locale: Locale) -> Formatters {
        Formatters(locale: locale, timeZone: timeZone, currencyCode: currencyCode, firstWeekday: firstWeekday)
    }
}
