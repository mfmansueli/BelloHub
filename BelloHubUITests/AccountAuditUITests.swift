//
//  AccountAuditUITests.swift
//  BelloHubUITests
//

import XCTest

/// Accessibility audit of the S10 screens (Account, Language and region, Plan, Notifications, Integrations, Privacy
/// and security, Export all my data, Recovery key, Help) in `en` and `ar`, at the default size and at AX5. Slow, so it
/// runs in the Full plan and is skipped by UISmoke. Exit criterion of S10: no clipped text and every element described,
/// right-to-left included.
@MainActor
final class AccountAuditUITests: XCTestCase {
    /// `TEST_RUNNER_AUDIT_LOCALES=en,ar scripts/test.sh ...` narrows the run to some localizations while iterating.
    private static let locales: [String] = {
        let chosen = ProcessInfo.processInfo.environment["AUDIT_LOCALES"]?.split(separator: ",").map(String.init)
        return chosen ?? ["en", "ar"]
    }()

    override func setUp() async throws {
        continueAfterFailure = true
    }

    func testAccountScreensAtDefaultSize() throws {
        try auditAccountScreens(largestText: false)
    }

    func testAccountScreensAtLargestSize() throws {
        try auditAccountScreens(largestText: true)
    }

    // MARK: - Walk

    private func auditAccountScreens(largestText: Bool) throws {
        for locale in Self.locales {
            let app = XCUIApplication.launchedForUITests(
                locale: locale, largestText: largestText, arguments: ["-uiSeed", "onboarded", "-uiPlan", "none"]
            )
            let tag = "\(locale)\(largestText ? " AX5" : "")"
            XCTAssertTrue(app.staticTexts["home.greeting"].waitForExistence(timeout: 8), "\(tag) home")
            app.tab(4).tap()
            XCTAssertTrue(app.buttons["more.accountRow"].waitForExistence(timeout: 5), "\(tag) more")
            try walkAccount(app, tag: tag)
            try walk(app, row: "more.planRow", first: app.buttons["plan.choice.yearly"], tag: "\(tag) plan")
            try walkNotificationsAndIntegrations(app, tag: tag)
            try walkPrivacy(app, tag: tag)
            try walk(app, row: "more.helpRow", first: app.buttons["help.contactButton"], tag: "\(tag) help") {
                app.element("help.topic.whereData").tap()
                XCTAssertTrue(app.element("help.answer.whereData").waitForExistence(timeout: 5))
                try self.audit(app, "\(tag) help with an answer open")
            }
            app.terminate()
        }
    }

    private func walkAccount(_ app: XCUIApplication, tag: String) throws {
        try walk(app, row: "more.accountRow", first: app.textFields["account.nameField"], tag: "\(tag) account") {
            app.tapButton("account.languageRegionRow")
            XCTAssertTrue(app.element("languageRegion.sets.currency").waitForExistence(timeout: 5))
            try self.audit(app, "\(tag) language and region")
            self.back(app)
            app.bringIntoView(app.buttons["account.deleteButton"])
            app.tapButton("account.deleteButton")
            XCTAssertTrue(app.buttons["deleteAccount.continueButton"].waitForExistence(timeout: 5))
            try self.audit(app, "\(tag) delete account, export offer")
            app.tapButton("deleteAccount.continueButton")
            XCTAssertTrue(app.buttons["deleteAccount.confirmButton"].waitForExistence(timeout: 5))
            try self.audit(app, "\(tag) delete account, confirmation")
            app.tapButton("deleteAccount.keepButton")
        }
    }

    private func walkNotificationsAndIntegrations(_ app: XCUIApplication, tag: String) throws {
        try walk(
            app, row: "more.notificationsRow", first: app.switches["notificationSettings.newBookingsSwitch"],
            tag: "\(tag) notifications"
        ) {
            // At AX5 the row stacks the label over the switch, so the flip tries several points until the pickers show.
            app.flipSwitch(
                "notificationSettings.quietHoursSwitch", opens: app.element("notificationSettings.quietFromPicker")
            )
            try self.audit(app, "\(tag) notifications with quiet hours")
        }
        try walk(
            app, row: "more.integrationsRow", first: app.switches["integrations.appleSwitch"],
            tag: "\(tag) integrations"
        )
    }

    private func walkPrivacy(_ app: XCUIApplication, tag: String) throws {
        try walk(app, row: "more.privacyRow", first: app.buttons["privacy.recoveryKeyRow"], tag: "\(tag) privacy") {
            app.tapButton("privacy.recoveryKeyRow")
            XCTAssertTrue(app.buttons["recoveryKey.revealButton"].waitForExistence(timeout: 5))
            try self.audit(app, "\(tag) recovery key, masked")
            app.tapButton("recoveryKey.revealButton")
            XCTAssertTrue(app.buttons["recoveryKey.confirmButton"].waitForExistence(timeout: 5))
            try self.audit(app, "\(tag) recovery key, revealed")
            self.back(app)
            app.bringIntoView(app.buttons["privacy.exportAllRow"])
            app.tapButton("privacy.exportAllRow")
            XCTAssertTrue(app.buttons["export.prepareButton"].waitForExistence(timeout: 5))
            try self.audit(app, "\(tag) export all")
            self.back(app)
            app.bringIntoView(app.buttons["privacy.legal.privacy-policy"])
            app.tapButton("privacy.legal.privacy-policy")
            XCTAssertTrue(app.element("legalNotice.body").waitForExistence(timeout: 5))
            try self.audit(app, "\(tag) privacy policy")
            app.tapButton("legalNotice.closeButton")
        }
    }

    /// Opens a More row, waits for `first`, audits the screen, runs `more`, and comes back to More.
    private func walk(
        _ app: XCUIApplication, row: String, first: XCUIElement, tag: String, more: () throws -> Void = {}
    ) throws {
        app.bringIntoView(app.buttons[row])
        app.tapButton(row)
        XCTAssertTrue(first.waitForExistence(timeout: 5), tag)
        try audit(app, tag)
        try more()
        back(app)
        XCTAssertTrue(app.buttons["more.accountRow"].waitForExistence(timeout: 5), "\(tag) back on More")
    }

    private func back(_ app: XCUIApplication) {
        app.navigationBars.buttons.element(boundBy: 0).tap()
    }

    /// Clipped text and missing descriptions only, as in the other audits: contrast is measured exactly by the unit
    /// tests (`PaletteContrastTests`), not by sampling pixels (CLAUDE.md section 5). The same false positives as
    /// `MoreAuditUITests` are ignored: Arabic text measured with Latin metrics, issues with no element on screen, and
    /// the system keyboard's own cells.
    private func audit(_ app: XCUIApplication, _ screen: String) throws {
        try app.performAccessibilityAudit(for: [.textClipped, .sufficientElementDescription]) { issue in
            let element = issue.element
            let systemKeyboard = ["TUIPredictionViewCell", "UIAlternativeCandidatesButton", "UIScriptSwitcherButton"]
            if systemKeyboard.contains(where: { issue.detailedDescription.contains($0) }) { return true }
            if issue.auditType == .textClipped, Self.isKnownFalsePositive(element) { return true }
            let names = [element?.identifier, element?.label].compactMap { $0 }.filter { !$0.isEmpty }
            let frame = element?.frame ?? .zero
            XCTFail(
                "[\(screen)] \(issue.compactDescription): \(names.joined(separator: " | ")) \(frame) -- " +
                    issue.detailedDescription
            )
            return true // reported above; keep auditing the rest of the screen
        }
    }

    private static func isKnownFalsePositive(_ element: XCUIElement?) -> Bool {
        guard let element, !element.frame.isEmpty || !element.label.isEmpty else { return true }
        let fallbackFontScripts = [0x0600...0x06FF, 0x0900...0x097F]
        return element.label.unicodeScalars.contains { scalar in
            fallbackFontScripts.contains { $0.contains(Int(scalar.value)) }
        }
    }
}
