//
//  LaunchUITests.swift
//  BelloHubUITests
//

import XCTest

@MainActor
final class LaunchUITests: XCTestCase {
    override func setUp() async throws {
        continueAfterFailure = false
    }

    func testFirstLaunchShowsTheWelcome() {
        let app = XCUIApplication.launchedForUITests()

        XCTAssertTrue(app.staticTexts["welcome.tagline"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["welcome.getStartedButton"].exists)
        XCTAssertTrue(app.buttons["welcome.signInButton"].exists)
    }

    func testASetUpWorkspaceOpensOnTheHomeScreen() {
        let app = XCUIApplication.launchedForUITests(arguments: ["-uiSeed", "onboarded"])

        XCTAssertTrue(app.staticTexts["home.greeting"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.tabBars.buttons.count, 5)
    }
}
