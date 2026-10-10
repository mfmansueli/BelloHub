//
//  AccessibilityAuditUITests.swift
//  BelloHubUITests
//

import XCTest

/// The S12 accessibility audit (docs/03-BUILD-PLAN.md S12, docs/13 section 4): `performAccessibilityAudit` with every
/// audit type on the key screens (onboarding, Home, New appointment, Alerts, More, Account, Plan, Privacy, Booking
/// page, Services, Clients list and profile, Calendar day and week, Record history), in `en` and `pt-BR`, at the
/// default size and at AX5, with Increase Contrast and Reduce Motion on (`-uiIncreaseContrast`, `-uiReduceMotion`).
/// Slow, so it only runs when asked:
/// `TEST_RUNNER_BELLO_A11Y=1 ONLY_TESTING=BelloHubUITests/AccessibilityAuditUITests scripts/test.sh full`
/// (`TEST_RUNNER_AUDIT_LOCALES=en` narrows it while iterating). The manual VoiceOver pass that complements it is
/// `docs/agent-notes/accessibility-audit.md`.
@MainActor
final class AccessibilityAuditUITests: XCTestCase {
    private static let locales: [String] = {
        let chosen = ProcessInfo.processInfo.environment["AUDIT_LOCALES"]?.split(separator: ",").map(String.init)
        return chosen ?? ["en", "pt-BR"]
    }()

    private static let settings = ["-uiIncreaseContrast", "-uiReduceMotion"]

    override func setUp() async throws {
        continueAfterFailure = true
        guard ProcessInfo.processInfo.environment["BELLO_A11Y"] == "1" else {
            throw XCTSkip("set TEST_RUNNER_BELLO_A11Y=1 to run the full accessibility audit")
        }
    }

    func testDefaultSize() throws {
        try walkEverything(largestText: false)
    }

    func testLargestSize() throws {
        try walkEverything(largestText: true)
    }

    // MARK: - Walks

    private func walkEverything(largestText: Bool) throws {
        for locale in Self.locales {
            let tag = "\(locale)\(largestText ? " AX5" : "")"
            try walkOnboarding(locale: locale, largestText: largestText, tag: tag)
            try walkWorkspace(locale: locale, largestText: largestText, tag: tag)
            try walkClientsAndCalendar(locale: locale, largestText: largestText, tag: tag)
            try walkRecordHistory(locale: locale, largestText: largestText, tag: tag)
        }
    }

    private func walkOnboarding(locale: String, largestText: Bool, tag: String) throws {
        let app = launch(locale: locale, largestText: largestText, arguments: [])
        XCTAssertTrue(app.staticTexts["welcome.tagline"].waitForExistence(timeout: 10), "\(tag) welcome")
        try audit(app, "\(tag) welcome")
        app.tapButton("welcome.phoneButton")
        XCTAssertTrue(app.staticTexts["signIn.title"].waitForExistence(timeout: 5), "\(tag) sign in")
        try audit(app, "\(tag) sign in")
        app.type("+14155552671", intoField: "signIn.phoneField")
        app.tapButton("signIn.sendButton")
        XCTAssertTrue(app.textFields["signIn.codeField"].waitForExistence(timeout: 5), "\(tag) code")
        app.type(XCUIApplication.developmentCode, intoField: "signIn.codeField")
        XCTAssertTrue(app.staticTexts["onboarding.about.title"].waitForExistence(timeout: 10), "\(tag) about")
        try audit(app, "\(tag) onboarding about")
        app.type("Maria Silva", intoField: "onboarding.about.nameField")
        app.tapButton("onboarding.about.continueButton")
        app.tapButton("onboarding.profession.choice.esthetician")
        try audit(app, "\(tag) onboarding profession")
        app.terminate()
    }

    private func walkWorkspace(locale: String, largestText: Bool, tag: String) throws {
        let app = launch(
            locale: locale, largestText: largestText,
            arguments: ["-uiSeed", "onboarded", "-uiHome", "-uiInbox", "fixtures"]
        )
        XCTAssertTrue(app.staticTexts["home.greeting"].waitForExistence(timeout: 15), "\(tag) home")
        try audit(app, "\(tag) home")
        app.swipeUp()
        try audit(app, "\(tag) home, lower half")
        app.scrollToTop()
        let newAppointment = app.buttons["home.quick.newAppointment"]
        app.bringIntoView(newAppointment)
        newAppointment.tap()
        XCTAssertTrue(app.buttons["newAppointment.cancelButton"].waitForExistence(timeout: 5), "\(tag) new appointment")
        try audit(app, "\(tag) new appointment")
        app.tapButton("newAppointment.cancelButton")

        app.openAlertsTab()
        try audit(app, "\(tag) alerts")

        app.tab(4).tap()
        XCTAssertTrue(app.buttons["more.accountRow"].waitForExistence(timeout: 5), "\(tag) more")
        try audit(app, "\(tag) more")
        try walkMoreRow(app, row: "more.accountRow", first: app.textFields["account.nameField"], tag: "\(tag) account")
        try walkMoreRow(app, row: "more.planRow", first: app.buttons["plan.choice.yearly"], tag: "\(tag) plan")
        try walkMoreRow(
            app, row: "more.privacyRow", first: app.buttons["privacy.recoveryKeyRow"], tag: "\(tag) privacy"
        )
        try walkMoreRow(
            app, row: "more.bookingPageRow", first: app.navigationBars.firstMatch, tag: "\(tag) booking page"
        )
        try walkMoreRow(app, row: "more.servicesRow", first: app.navigationBars.firstMatch, tag: "\(tag) services")
        app.terminate()
    }

    private func walkClientsAndCalendar(locale: String, largestText: Bool, tag: String) throws {
        let app = launch(
            locale: locale, largestText: largestText,
            arguments: ["-uiSeed", "clients", "-uiCalendar", "-uiCalendarVisits"]
        )
        app.openClientsTab()
        XCTAssertTrue(app.clientRows.firstMatch.waitForExistence(timeout: 15), "\(tag) client list")
        try audit(app, "\(tag) clients")
        app.clientRows.firstMatch.tap()
        XCTAssertTrue(app.staticTexts["clientProfile.name"].waitForExistence(timeout: 5), "\(tag) profile")
        try audit(app, "\(tag) client profile")
        app.swipeUp()
        try audit(app, "\(tag) client profile, lower half")

        app.openCalendarTab()
        try audit(app, "\(tag) calendar day")
        let modes = app.segmentedControls["calendar.modePicker"]
        if modes.waitForExistence(timeout: 5) {
            modes.buttons.element(boundBy: 1).tap()
            try audit(app, "\(tag) calendar week")
        }
        app.terminate()
    }

    private func walkRecordHistory(locale: String, largestText: Bool, tag: String) throws {
        let app = launch(
            locale: locale, largestText: largestText,
            arguments: ["-uiSeed", "clientWithHealth", "-uiRecords", "-uiRoute", "recordHistory"]
        )
        XCTAssertTrue(app.element("recordHistory.overview").waitForExistence(timeout: 30), "\(tag) record history")
        try audit(app, "\(tag) record history")
        app.swipeUp()
        try audit(app, "\(tag) record history, lower half")
        app.terminate()
    }

    // MARK: - Helpers

    private func launch(locale: String, largestText: Bool, arguments: [String]) -> XCUIApplication {
        XCUIApplication.launchedForUITests(
            locale: locale, largestText: largestText, arguments: arguments + Self.settings
        )
    }

    private func walkMoreRow(_ app: XCUIApplication, row: String, first: XCUIElement, tag: String) throws {
        app.bringIntoView(app.buttons[row])
        app.tapButton(row)
        XCTAssertTrue(first.waitForExistence(timeout: 8), tag)
        try audit(app, tag)
        app.swipeUp()
        try audit(app, "\(tag), lower half")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.buttons["more.accountRow"].waitForExistence(timeout: 5), "\(tag) back on More")
    }

    /// Every audit type. Ignored, as in the other audits: issues with no element on screen, navigation-bar titles the
    /// audit measures before the bar lays them out, and the system's own views (keyboard, status bar).
    private func audit(_ app: XCUIApplication, _ screen: String) throws {
        try app.performAccessibilityAudit(for: .all) { issue in
            guard let element = issue.element, !(element.label.isEmpty && element.frame == .zero) else { return true }
            let bar = app.navigationBars.firstMatch.frame
            let center = CGPoint(x: element.frame.midX, y: element.frame.midY)
            if issue.auditType == .textClipped, element.elementType == .staticText, !bar.isEmpty, bar.contains(center) {
                return true
            }
            let names = [element.identifier, element.label].filter { !$0.isEmpty }
            XCTFail(
                "[\(screen)] \(issue.compactDescription): \(names.joined(separator: " | ")) \(element.frame) -- "
                    + issue.detailedDescription
            )
            return true
        }
    }
}
