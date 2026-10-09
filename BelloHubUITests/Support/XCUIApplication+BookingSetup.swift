//
//  XCUIApplication+BookingSetup.swift
//  BelloHubUITests
//

import XCTest

extension XCUIApplication {
    /// The state `-uiSeed onboarded` leaves: a signed-in professional ("Maria Silva") with her workspace set up, on
    /// Home. The booking setup (hours, page, policies, quick replies) starts from its defaults, as for a new account.
    @MainActor
    static func launchedOnBookingSetup(locale: String? = nil, largestText: Bool = false) -> XCUIApplication {
        launchedForUITests(locale: locale, largestText: largestText, arguments: ["-uiSeed", "onboarded"])
    }

    /// Opens the More tab and pushes the screen behind `rowIdentifier`.
    @MainActor
    func openMoreRow(_ rowIdentifier: String, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(
            staticTexts["home.greeting"].waitForExistence(timeout: 8), "no Home", file: file, line: line
        )
        tab(4).tap()
        tapButton(rowIdentifier, file: file, line: line)
    }

    /// Taps the switch with this identifier. A switch in a card row reports the whole row as its frame and its center
    /// is the label, so the tap goes to the trailing edge where the control is (the flows run in a left-to-right
    /// language).
    @MainActor
    func flipSwitch(_ identifier: String, file: StaticString = #filePath, line: UInt = #line) {
        let toggle = switches[identifier]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5), "no switch \(identifier)", file: file, line: line)
        toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
    }

    /// Waits until the element is no longer there.
    @MainActor
    func waitUntilGone(_ element: XCUIElement, timeout: TimeInterval = 5) -> Bool {
        let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: element)
        return XCTWaiter().wait(for: [gone], timeout: timeout) == .completed
    }

    /// Scrolls up the screen until `element` exists: a list builds only the rows near the screen, and at AX5 the row
    /// the test wants can be several screens down.
    @MainActor
    func scrollUntilExists(_ element: XCUIElement, limit: Int = 24) -> Bool {
        let start = coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.7))
        let end = coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.45))
        var drags = 0
        while !element.waitForExistence(timeout: 1.5), drags < limit {
            start.press(forDuration: 0.05, thenDragTo: end)
            drags += 1
        }
        return element.exists
    }
}
