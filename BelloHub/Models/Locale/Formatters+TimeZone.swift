//
//  Formatters+TimeZone.swift
//  BelloHub
//

import Foundation

extension Formatters {
    /// A time zone as a person names it, in the reader's language: its city ("Rome", "Roma", "روما"), from CLDR, never
    /// a hard-coded name. A zone without a city (`Etc/GMT+3`, `GMT`) reads as its offset ("GMT-03:00"), because CLDR
    /// would answer "Unknown City".
    func zoneName(_ zone: TimeZone, at date: Date) -> String {
        let id = zone.identifier
        let hasCity = id.contains("/") && !id.hasPrefix("Etc/")
        let style = Date.FormatStyle(locale: locale, calendar: calendar, timeZone: zone)
            .timeZone(hasCity ? .exemplarLocation : .localizedGMT(.long))
        return date.formatted(style)
    }
}
