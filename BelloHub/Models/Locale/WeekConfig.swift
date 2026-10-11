//
//  WeekConfig.swift
//  BelloHub
//

import Foundation

/// First day of the week and 12 or 24 hour clock. Defaults come from Foundation for the business
/// region and are stored in `LocalePrefs`, so the professional can override them (D25). Tests assert
/// the values Foundation gives, plus the short list in docs/07-LOCALIZATION.md section 2.4.
struct WeekConfig: Equatable, Sendable {
    /// 1 is Sunday and 2 is Monday, as in `Calendar.firstWeekday`.
    var firstWeekday: Int
    var use24Hour: Bool

    static func defaults(forRegion code: String, languageCode: String = "en") -> WeekConfig {
        let locale = Locale(identifier: "\(languageCode)_\(code)")
        let calendar = Calendar(identifier: .gregorian)
        let region = Locale(identifier: "und_\(code)")
        // `Calendar(identifier:)` ignores the locale, so the region's week start is read from a
        // calendar built for that locale.
        var localized = calendar
        localized.locale = region
        return WeekConfig(firstWeekday: localized.firstWeekday, use24Hour: locale.hourCycle == .zeroToTwentyThree
            || locale.hourCycle == .oneToTwentyFour)
    }

    /// The week start and clock in force: her own choice (Language and region) where she made one, otherwise her
    /// region's. The one owner of this rule: the calendar, Availability, Booking settings and Language and region all
    /// read it, so the week can never start on one day in one screen and on another day in the next.
    static func effective(
        regionCode: String, languageCode: String, firstWeekday: Int?, use24Hour: Bool?
    ) -> WeekConfig {
        let region = defaults(forRegion: regionCode, languageCode: languageCode)
        return WeekConfig(firstWeekday: firstWeekday ?? region.firstWeekday, use24Hour: use24Hour ?? region.use24Hour)
    }
}
