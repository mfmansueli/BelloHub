//
//  XCUIApplication+Appointments.swift
//  BelloHubUITests
//

import XCTest

extension XCUIApplication {
    /// Launches on the list of the two seeded visits (`-uiRoute appointments`), which push the real visit detail.
    @MainActor
    static func launchedOnAppointments(locale: String? = nil, largestText: Bool = false) -> XCUIApplication {
        launchedForUITests(
            locale: locale, largestText: largestText, arguments: ["-uiSeed", "appointments", "-uiRoute", "appointments"]
        )
    }

    /// Scrolls the visit detail until this button is on screen, then taps it.
    @MainActor
    func scrollToAndTap(_ identifier: String, file: StaticString = #filePath, line: UInt = #line) {
        let button = buttons[identifier].firstMatch
        XCTAssertTrue(button.waitForExistence(timeout: 8), "no button \(identifier)", file: file, line: line)
        var swipes = 0
        while !button.isHittable, swipes < 8 {
            swipeUp()
            swipes += 1
        }
        button.tap()
    }
}
