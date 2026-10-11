//
//  XCUIApplication+TimeZoneNotice.swift
//  BelloHubUITests
//

import XCTest

extension XCUIApplication {
    /// Launches the onboarded professional (business in São Paulo) with the iPhone in `phoneTimeZone` (`TZ` moves the
    /// whole process) and the time-zone notice allowed (`-uiTimeZoneNotice`), on `tab`.
    @MainActor
    static func launchedWithPhoneZone(
        _ phoneTimeZone: String, tab: String = "home", locale: String? = nil, largestText: Bool = false
    ) -> XCUIApplication {
        let app = launchedForUITests(
            locale: locale, largestText: largestText,
            arguments: ["-uiSeed", "onboarded", "-uiTimeZoneNotice", "-uiTab", tab],
            environment: ["TZ": phoneTimeZone]
        )
        let landmark = tab == "calendar" ? app.element("calendar.modePicker") : app.staticTexts["home.greeting"]
        XCTAssertTrue(landmark.waitForExistence(timeout: 10), "\(tab) did not open")
        return app
    }

    /// An item of a menu: iOS does not always pass a SwiftUI identifier to the buttons it draws for a menu, so the
    /// English label is the fallback (tests that use it run in English).
    @MainActor
    func menuItem(_ identifier: String, englishLabel: String) -> XCUIElement {
        let byID = buttons[identifier].firstMatch
        if byID.waitForExistence(timeout: 3) { return byID }
        return buttons[englishLabel].firstMatch
    }
}
