//
//  XCUIApplication+Home.swift
//  BelloHubUITests
//

import XCTest

extension XCUIApplication {
    /// Launches on Home with the `-uiHome` visits (one earlier today, the next in half an hour, one in three hours
    /// with a reminder ready, a client who has not been back and a birthday tomorrow).
    @MainActor
    static func launchedOnHome(locale: String? = nil, largestText: Bool = false) -> XCUIApplication {
        let app = launchedForUITests(
            locale: locale, largestText: largestText, arguments: ["-uiSeed", "onboarded", "-uiHome"]
        )
        XCTAssertTrue(app.staticTexts["home.greeting"].waitForExistence(timeout: 10), "Home did not open")
        return app
    }

    /// The Alerts tab is the fourth one in the system tab bar.
    @MainActor
    func openAlertsTab() {
        let tab = tab(3)
        XCTAssertTrue(tab.waitForExistence(timeout: 5), "no Alerts tab")
        tab.tap()
        XCTAssertTrue(element("alerts.subtitle").waitForExistence(timeout: 10), "Alerts did not open")
    }

    /// The elements of a family (`home.visit.`, `reminders.send.`): a test does not know the ids of the seeded data.
    @MainActor
    func elements(prefix: String) -> XCUIElementQuery {
        descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH %@", prefix))
    }

    /// Scrolls a screen until the first element of a family can be tapped, then taps it.
    @MainActor
    func scrollToAndTap(prefix: String, file: StaticString = #filePath, line: UInt = #line) {
        let target = elements(prefix: prefix).firstMatch
        XCTAssertTrue(target.waitForExistence(timeout: 8), "nothing starts with \(prefix)", file: file, line: line)
        var swipes = 0
        while !target.isHittable, swipes < 8 {
            swipeUp()
            swipes += 1
        }
        target.tap()
    }

    /// Scrolls back to the top of a scrolling screen.
    @MainActor
    func scrollToTop() {
        var swipes = 0
        while !staticTexts["home.greeting"].isHittable, swipes < 8 {
            swipeDown()
            swipes += 1
        }
    }
}
