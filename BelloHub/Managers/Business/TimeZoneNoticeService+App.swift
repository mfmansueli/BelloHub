//
//  TimeZoneNoticeService+App.swift
//  BelloHub
//

import Foundation

extension TimeZoneNoticeService {
    /// The app's instance. A UI-test launch shows the notice only with `-uiTimeZoneNotice`: the simulator follows the
    /// Mac's zone while the seeded business is in São Paulo, so every other test would meet it.
    static func forApp(defaults: UserDefaults, regions: RegionCatalog) -> TimeZoneNoticeService {
        #if DEBUG
        let options = LaunchOptions.current
        let isEnabled = !options.isUITesting || options.showsTimeZoneNotice
        #else
        let isEnabled = true
        #endif
        return TimeZoneNoticeService(defaults: defaults, regions: regions, isEnabled: isEnabled)
    }
}
