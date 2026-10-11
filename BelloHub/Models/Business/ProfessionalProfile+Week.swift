//
//  ProfessionalProfile+Week.swift
//  BelloHub
//

import Foundation

extension ProfessionalProfile {
    /// Her week start and clock in force: what she chose in Language and region, otherwise her region's.
    var weekConfig: WeekConfig {
        WeekConfig.effective(
            regionCode: regionCode, languageCode: AppLocalization(rawValue: appLocaleID)?.languageCode ?? "en",
            firstWeekday: firstWeekday, use24Hour: use24Hour
        )
    }
}
