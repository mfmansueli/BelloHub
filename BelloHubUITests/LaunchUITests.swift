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

    func testLaunchShowsHomeGreeting() {
        let app = XCUIApplication.launchedForUITests()

        XCTAssertTrue(app.staticTexts["home.greeting"].waitForExistence(timeout: 5))
    }
}
