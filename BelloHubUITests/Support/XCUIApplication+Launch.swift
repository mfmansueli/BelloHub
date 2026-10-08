//
//  XCUIApplication+Launch.swift
//  BelloHubUITests
//

import XCTest

extension XCUIApplication {
    /// The only way UI tests start the app: `-uiTesting` makes the app run without animations.
    /// Add launch arguments for a controlled initial state here, never in individual tests.
    @MainActor
    static func launchedForUITests() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTesting"]
        app.launch()
        return app
    }
}
