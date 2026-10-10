//
//  ColorReviewUITests.swift
//  BelloHubUITests
//

import XCTest

/// Not a check: a design-review tool that saves screenshots of the key screen families (welcome, Home with visits and
/// empty, Calendar, Alerts, Clients, a client, a form sheet and the Design Catalog) in light and dark, for comparing a palette change with its reference.
/// It only runs when a folder is given, so every plan skips it:
/// `TEST_RUNNER_SCREENSHOT_DIR=$PWD/build/screenshots ONLY_TESTING=BelloHubUITests/ColorReviewUITests \`
/// `scripts/test.sh full`.
@MainActor
final class ColorReviewUITests: XCTestCase {
    private var folder = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)

    override func setUp() async throws {
        continueAfterFailure = true
        guard let path = ProcessInfo.processInfo.environment["SCREENSHOT_DIR"], !path.isEmpty else {
            throw XCTSkip("set TEST_RUNNER_SCREENSHOT_DIR to save the review screenshots")
        }
        folder = URL(fileURLWithPath: path, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    func testScreensInLightAndDark() {
        for mode in ["light", "dark"] {
            homeAndSheet(mode: mode)
            entryAndEmptyHome(mode: mode)
            tabs(mode: mode)
            catalog(mode: mode)
        }
    }

    // MARK: - Helpers

    private func homeAndSheet(mode: String) {
        let app = XCUIApplication.launchedForUITests(arguments: ["-uiSeed", "onboarded", "-uiHome"] + dark(mode))
        _ = app.staticTexts["home.greeting"].waitForExistence(timeout: 10)
        save(app, "home-\(mode)")
        app.swipeUp()
        save(app, "home-tiles-\(mode)")
        let newAppointment = app.buttons["home.quick.newAppointment"]
        if newAppointment.waitForExistence(timeout: 5) {
            if !newAppointment.isHittable { app.swipeUp() }
            newAppointment.tap()
            _ = app.buttons["newAppointment.cancelButton"].waitForExistence(timeout: 5)
            save(app, "sheet-new-appointment-\(mode)")
        }
        app.terminate()
    }

    /// The welcome screen (the mark, the pill, the glow backdrop) and Home on a clear day (the empty state).
    private func entryAndEmptyHome(mode: String) {
        let welcome = XCUIApplication.launchedForUITests(arguments: dark(mode))
        _ = welcome.buttons["welcome.phoneButton"].waitForExistence(timeout: 10)
        save(welcome, "welcome-\(mode)")
        welcome.terminate()
        let app = XCUIApplication.launchedForUITests(arguments: ["-uiSeed", "onboarded"] + dark(mode))
        _ = app.element("home.empty").waitForExistence(timeout: 10)
        save(app, "home-empty-\(mode)")
        app.terminate()
    }

    private func tabs(mode: String) {
        let app = XCUIApplication.launchedForUITests(
            arguments: ["-uiSeed", "onboarded", "-uiHome", "-uiInbox", "fixtures"] + dark(mode)
        )
        app.openCalendarTab()
        save(app, "calendar-\(mode)")
        app.openAlertsTab()
        save(app, "alerts-\(mode)")
        app.openClientsTab()
        save(app, "clients-\(mode)")
        let row = app.clientRows.firstMatch
        if row.waitForExistence(timeout: 5) {
            row.tap()
            waitForPush()
            save(app, "client-profile-\(mode)")
        }
        app.terminate()
    }

    private func catalog(mode: String) {
        for section in ["buttons", "components", "colors"] {
            var arguments = ["-designCatalog", "-catalogSection", section]
            if mode == "dark" { arguments.append("-catalogDark") }
            let app = XCUIApplication.launchedForUITests(arguments: arguments)
            _ = app.element("catalog.section.\(section)").waitForExistence(timeout: 10)
            // The catalog applies its appearance a moment after the first frame, which no element reflects; a short
            // wait on an element that never appears lets it settle (a screenshot tool, nothing is asserted).
            _ = app.element("colorReview.never").waitForExistence(timeout: 1.5)
            save(app, "catalog-\(section)-\(mode)")
            app.terminate()
        }
    }

    /// The pushed profile has no identifier shared by every seed, so the screenshot waits on its navigation bar; a
    /// tool, not a check, so nothing is asserted on the wait.
    private func waitForPush() {
        _ = XCUIApplication().navigationBars.firstMatch.waitForExistence(timeout: 3)
    }

    /// The simulator's own appearance switch does not reach the app, so dark comes from the app's `-uiDark` hook.
    private func dark(_ mode: String) -> [String] {
        mode == "dark" ? ["-uiDark"] : []
    }

    private func save(_ app: XCUIApplication, _ name: String) {
        let url = folder.appendingPathComponent("\(name).png")
        try? app.screenshot().pngRepresentation.write(to: url)
    }
}
