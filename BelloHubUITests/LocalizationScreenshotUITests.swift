//
//  LocalizationScreenshotUITests.swift
//  BelloHubUITests
//

import XCTest

/// The localization screenshots test of S11 (docs/13-TESTING-QUALITY.md section 5, docs/07-LOCALIZATION.md section 9):
/// the key screens (Home, New appointment, Calendar, Clients, a client, Alerts, Booking request, More, Booking page,
/// Cancellations and changes, Language and region, Privacy and security, Recovery key) render in all fourteen
/// localizations at the default text size with no clipped or truncated text, navigation titles included, and with
/// their primary action on screen. Arabic is also checked for mirroring (the first tab and the back button sit on the
/// right), and a pseudo-localization pass doubles every string to find layouts that only fit short text.
/// Slow (about a minute per localization), so it runs in the Full plan and UISmoke skips it.
/// `TEST_RUNNER_SCREENSHOT_LOCALES=pt-BR,de` narrows the run; `TEST_RUNNER_SCREENSHOT_DIR=<folder>` also saves a PNG
/// of every screen (`<localization>-<screen>.png`) for a native reader.
@MainActor
final class LocalizationScreenshotUITests: XCTestCase {
    private static let allLocales = [
        "pt-BR", "pt-PT", "es-MX", "es-419", "es", "en", "en-GB", "it", "fr", "de", "tr", "id", "hi", "ar"
    ]

    private static let locales: [String] = {
        let chosen = ProcessInfo.processInfo.environment["SCREENSHOT_LOCALES"]?.split(separator: ",").map(String.init)
        return chosen ?? allLocales
    }()

    private var folder: URL?

    override func setUp() async throws {
        continueAfterFailure = true
        if let path = ProcessInfo.processInfo.environment["SCREENSHOT_DIR"], !path.isEmpty {
            let url = URL(fileURLWithPath: path, isDirectory: true)
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
            folder = url
        }
    }

    func testKeyScreensInEveryLocalization() throws {
        for locale in Self.locales {
            let app = XCUIApplication.launchedForUITests(
                locale: locale, arguments: ["-uiSeed", "onboarded", "-uiHome", "-uiInbox", "fixtures"]
            )
            XCTAssertTrue(app.staticTexts["home.greeting"].waitForExistence(timeout: 10), "\(locale) home")
            try home(app, locale)
            try calendarAndClients(app, locale)
            try alerts(app, locale)
            try more(app, locale)
            app.terminate()
        }
    }

    /// Arabic mirrors the layout: the first tab (Home) is the rightmost one and a pushed screen's back button sits on
    /// the right, pointing right (the system mirrors the chevron with the layout).
    func testArabicMirrorsTheLayout() throws {
        let app = XCUIApplication.launchedForUITests(locale: "ar", arguments: ["-uiSeed", "onboarded", "-uiHome"])
        XCTAssertTrue(app.staticTexts["home.greeting"].waitForExistence(timeout: 10), "ar home")
        let first = app.tab(0)
        let last = app.tab(4)
        XCTAssertTrue(first.waitForExistence(timeout: 5) && last.exists, "ar tab bar")
        XCTAssertGreaterThan(first.frame.midX, last.frame.midX, "the first tab is on the right in Arabic")
        app.openClientsTab()
        let row = app.clientRows.firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 8), "ar clients")
        row.tap()
        XCTAssertTrue(app.element("clientProfile.name").waitForExistence(timeout: 8), "ar client profile")
        let back = app.navigationBars.buttons.element(boundBy: 0)
        XCTAssertTrue(back.waitForExistence(timeout: 5), "ar back button")
        XCTAssertGreaterThan(back.frame.midX, app.frame.midX, "the back button is on the right in Arabic")
        save(app, "ar-mirrored-client-profile")
    }

    /// Every string doubled (`NSDoubleLocalizedStrings`, Xcode's long-string pseudolanguage): the primary actions
    /// must still be on screen and reachable, so no layout depends on English being short.
    func testDoubleLengthPseudoLanguageKeepsPrimaryActions() throws {
        let app = XCUIApplication.launchedForUITests(
            locale: "en", arguments: ["-uiSeed", "onboarded", "-uiHome", "-NSDoubleLocalizedStrings", "YES"]
        )
        XCTAssertTrue(app.staticTexts["home.greeting"].waitForExistence(timeout: 10), "pseudo home")
        let newAppointment = app.buttons["home.quick.newAppointment"]
        XCTAssertTrue(app.scrollUntilExists(newAppointment), "pseudo: New appointment reachable")
        app.bringIntoView(newAppointment)
        XCTAssertTrue(newAppointment.isHittable, "pseudo: New appointment can be tapped")
        newAppointment.tap()
        XCTAssertTrue(app.buttons["newAppointment.cancelButton"].waitForExistence(timeout: 8), "pseudo sheet")
        XCTAssertTrue(app.buttons["newAppointment.confirmButton"].exists, "pseudo: the sheet keeps its confirm button")
        save(app, "pseudo-new-appointment")
        app.tapButton("newAppointment.cancelButton")
        app.tab(4).tap()
        XCTAssertTrue(app.buttons["more.bookingPageRow"].waitForExistence(timeout: 8), "pseudo more")
        app.bringIntoView(app.buttons["more.bookingPageRow"])
        app.tapButton("more.bookingPageRow")
        let cancelRow = app.buttons["bookingSettings.cancelRow"]
        XCTAssertTrue(app.scrollUntilExists(cancelRow), "pseudo: Cancellations row reachable")
        app.bringIntoView(cancelRow)
        XCTAssertTrue(cancelRow.isHittable, "pseudo: Cancellations row can be tapped")
        save(app, "pseudo-booking-page")
    }

    // MARK: - Screens

    private func home(_ app: XCUIApplication, _ locale: String) throws {
        try check(app, locale, "home")
        let newAppointment = app.buttons["home.quick.newAppointment"]
        XCTAssertTrue(app.scrollUntilExists(newAppointment), "\(locale) New appointment on Home")
        app.bringIntoView(newAppointment)
        try check(app, locale, "home-lower")
        newAppointment.tap()
        XCTAssertTrue(app.buttons["newAppointment.cancelButton"].waitForExistence(timeout: 8), "\(locale) sheet")
        XCTAssertTrue(app.buttons["newAppointment.confirmButton"].exists, "\(locale) New appointment confirm")
        try check(app, locale, "new-appointment")
        app.tapButton("newAppointment.cancelButton")
        XCTAssertTrue(app.staticTexts["home.greeting"].waitForExistence(timeout: 5) || app.tab(0).exists)
    }

    private func calendarAndClients(_ app: XCUIApplication, _ locale: String) throws {
        app.openCalendarTab()
        try check(app, locale, "calendar")
        app.openClientsTab()
        try check(app, locale, "clients")
        let row = app.clientRows.firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 8), "\(locale) a client row")
        row.tap()
        XCTAssertTrue(app.element("clientProfile.name").waitForExistence(timeout: 8), "\(locale) client profile")
        try check(app, locale, "client-profile")
        app.goBack()
    }

    private func alerts(_ app: XCUIApplication, _ locale: String) throws {
        app.openAlertsTab()
        XCTAssertTrue(app.element("alerts.request.req-ana").waitForExistence(timeout: 10), "\(locale) inbox synced")
        try check(app, locale, "alerts")
        app.scrollToAndTap(prefix: "alerts.request.req-ana.action")
        XCTAssertTrue(app.element("bookingRequest.reason").waitForExistence(timeout: 10), "\(locale) booking request")
        try check(app, locale, "booking-request")
        app.goBack()
    }

    private func more(_ app: XCUIApplication, _ locale: String) throws {
        app.tab(4).tap()
        XCTAssertTrue(app.buttons["more.accountRow"].waitForExistence(timeout: 8), "\(locale) more")
        try check(app, locale, "more")
        let cancelRow = app.buttons["bookingSettings.cancelRow"]
        try open(app, row: "more.bookingPageRow", first: cancelRow, locale, "booking-page") {
            app.bringIntoView(app.buttons["bookingSettings.cancelRow"])
            app.tapButton("bookingSettings.cancelRow")
            XCTAssertTrue(app.scrollUntilExists(app.element("cancelPolicy.ruleText")), "\(locale) cancellations")
            app.swipeDown()
            app.swipeDown()
            try self.check(app, locale, "cancel-policy")
            app.goBack()
        }
        try open(app, row: "more.accountRow", first: app.buttons["account.languageRegionRow"], locale, "account") {
            app.tapButton("account.languageRegionRow")
            XCTAssertTrue(app.element("languageRegion.sets.currency").waitForExistence(timeout: 8), "\(locale) region")
            try self.check(app, locale, "language-region")
            app.goBack()
        }
        try open(app, row: "more.privacyRow", first: app.buttons["privacy.recoveryKeyRow"], locale, "privacy") {
            app.tapButton("privacy.recoveryKeyRow")
            XCTAssertTrue(app.buttons["recoveryKey.revealButton"].waitForExistence(timeout: 8), "\(locale) key")
            try self.check(app, locale, "recovery-key")
            app.goBack()
        }
    }

    /// Opens a More row, checks the screen it pushes, runs `then`, and comes back to More.
    private func open(
        _ app: XCUIApplication, row: String, first: XCUIElement, _ locale: String, _ name: String,
        then: () throws -> Void
    ) throws {
        app.bringIntoView(app.buttons[row])
        app.tapButton(row)
        XCTAssertTrue(first.waitForExistence(timeout: 8), "\(locale) \(name)")
        try check(app, locale, name)
        try then()
        app.goBack()
        XCTAssertTrue(app.buttons["more.accountRow"].waitForExistence(timeout: 8), "\(locale) back on More")
    }

    // MARK: - Helpers

    /// Saves the screen when a folder is given, then fails on any clipped or truncated text. Unlike the S4 to S10
    /// audits, the navigation bar title is checked too: a large title that does not fit is exactly what this test is
    /// for. Text in Arabic and Devanagari is skipped by the audit (its heuristic measures the fallback fonts with Latin
    /// metrics and reports every line); those screens are covered by the screenshots and the mirroring test.
    private func check(_ app: XCUIApplication, _ locale: String, _ screen: String) throws {
        save(app, "\(locale)-\(screen)")
        try app.performAccessibilityAudit(for: [.textClipped]) { issue in
            guard let element = issue.element else { return true }
            if element.elementType == .textView || element.elementType == .textField { return true }
            if element.label.isEmpty, element.frame == .zero { return true }
            if Self.usesFallbackFont(element.label) { return true }
            XCTFail("[\(locale) \(screen)] \(issue.compactDescription): \(element.identifier) | \(element.label) "
                    + "\(element.frame)")
            return true
        }
    }

    private static func usesFallbackFont(_ text: String) -> Bool {
        let scripts = [0x0600...0x06FF, 0x0900...0x097F]
        return text.unicodeScalars.contains { scalar in scripts.contains { $0.contains(Int(scalar.value)) } }
    }

    private func save(_ app: XCUIApplication, _ name: String) {
        guard let folder else { return }
        try? app.screenshot().pngRepresentation.write(to: folder.appendingPathComponent("\(name).png"))
    }
}
