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
}
