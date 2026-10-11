//
//  DesignCatalogUITests.swift
//  BelloHubUITests
//

import XCTest

/// The Design Catalog is reachable with `-designCatalog` (DEBUG only). These tests prove it renders and that
/// right-to-left mirrors the layout.
@MainActor
final class DesignCatalogUITests: XCTestCase {
    override func setUp() async throws {
        continueAfterFailure = false
    }

    func testCatalogShowsItsSections() {
        let app = XCUIApplication.launchedForUITests(arguments: ["-designCatalog"])

        XCTAssertTrue(app.otherElements["catalog.root"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["catalog.options"].exists)
        app.terminate()

        // Sections below the fold are not in the accessibility tree until scrolled to, so ask for one.
        let buttons = XCUIApplication.launchedForUITests(arguments: ["-designCatalog", "-catalogSection", "buttons"])
        XCTAssertTrue(buttons.buttons["catalog.button.primary"].waitForExistence(timeout: 5))
    }

    func testRightToLeftPutsTheFirstChipOnTheRight() {
        let leftToRight = XCUIApplication.launchedForUITests(
            locale: "en", arguments: ["-designCatalog", "-catalogSection", "buttons"]
        )
        XCTAssertTrue(leftToRight.buttons["catalog.chip.0"].waitForExistence(timeout: 5))
        let leftToRightFirst = leftToRight.buttons["catalog.chip.0"].frame.midX
        let leftToRightSecond = leftToRight.buttons["catalog.chip.1"].frame.midX
        leftToRight.terminate()

        let rightToLeft = XCUIApplication.launchedForUITests(
            locale: "ar", arguments: ["-designCatalog", "-catalogSection", "buttons"]
        )
        XCTAssertTrue(rightToLeft.buttons["catalog.chip.0"].waitForExistence(timeout: 5))

        XCTAssertLessThan(leftToRightFirst, leftToRightSecond, "in English the first chip is on the left")
        XCTAssertGreaterThan(
            rightToLeft.buttons["catalog.chip.0"].frame.midX, rightToLeft.buttons["catalog.chip.1"].frame.midX,
            "in Arabic the first chip is on the right"
        )
    }
}
