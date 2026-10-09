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
    /// is the label, so the tap goes to the edge where the control is: the trailing one, which is the right in a
    /// left-to-right language and the left in Arabic, so both are tried. A switch that only opens a sheet keeps its
    /// value, so `opens` names what appears when the tap worked.
    @MainActor
    func flipSwitch(
        _ identifier: String, opens target: XCUIElement? = nil, file: StaticString = #filePath, line: UInt = #line
    ) {
        let toggle = switches[identifier]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5), "no switch \(identifier)", file: file, line: line)
        bringIntoView(toggle)
        let before = toggle.value as? String ?? ""
        // Where the control is: at the middle of the trailing or leading edge, or lower when a large text size stacks
        // the label above it.
        for point in [(0.92, 0.5), (0.08, 0.5), (0.92, 0.85), (0.08, 0.85), (0.5, 0.5), (0.5, 0.9)] {
            toggle.coordinate(withNormalizedOffset: CGVector(dx: point.0, dy: point.1)).tap()
            if let target {
                if target.waitForExistence(timeout: 2) { return }
            } else {
                let changed = XCTNSPredicateExpectation(
                    predicate: NSPredicate(format: "value != %@", before), object: toggle
                )
                if XCTWaiter().wait(for: [changed], timeout: 2) == .completed { return }
            }
        }
        XCTFail("the switch \(identifier) did not respond", file: file, line: line)
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

    /// Scrolls until the element sits clear of the navigation bar and the tab bar, so a tap at a point of its frame
    /// lands on it and not on what the bars float over. At the largest text size a row can be half under the bar when
    /// it first exists.
    @MainActor
    func bringIntoView(_ element: XCUIElement, attempts: Int = 24) {
        let screen = windows.firstMatch.frame
        for _ in 0..<attempts {
            let frame = element.frame
            let tooHigh = frame.minY < 150
            let tooLow = frame.maxY > screen.maxY - 150
            guard tooHigh || tooLow else { return }
            // A long drag when it is far away (a very long page at the largest size), a short one when it is close.
            let far = frame.minY < -200 || frame.maxY > screen.maxY + 200
            let near = far ? 0.2 : 0.45
            let distant = far ? 0.8 : 0.7
            let from = coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: tooHigh ? near : distant))
            let to = coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: tooHigh ? distant : near))
            from.press(forDuration: 0.05, thenDragTo: to)
        }
    }
}
