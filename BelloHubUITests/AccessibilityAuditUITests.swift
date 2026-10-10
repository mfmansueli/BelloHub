//
//  AccessibilityAuditUITests.swift
//  BelloHubUITests
//

import XCTest

/// The S12 accessibility audit (docs/03-BUILD-PLAN.md S12, docs/13 section 4): `performAccessibilityAudit` with every
/// audit type on the key screens (onboarding, Home, New appointment, Alerts, More, Account, Plan, Privacy, Booking
/// page, Services, Clients list and profile, Calendar day and week, Record history), in `en` and `pt-BR`, at the
/// default size and at AX5, with Increase Contrast and Reduce Motion on (`-uiIncreaseContrast`, `-uiReduceMotion`).
/// The Full plan runs it in `en` (`BELLO_A11Y=1`, `AUDIT_PLAN_LOCALES=en` in `Full.xctestplan`, S12: Increase Contrast
/// and Reduce Motion in every Full run; the per-feature audits cover pt-BR, de, ar and hi). Both languages:
/// `TEST_RUNNER_BELLO_A11Y=1 TEST_RUNNER_AUDIT_LOCALES=en,pt-BR
/// ONLY_TESTING=BelloHubUITests/AccessibilityAuditUITests scripts/test.sh full`
/// (`TEST_RUNNER_AUDIT_LOCALES` also narrows it while iterating). The manual VoiceOver pass that complements it is
/// `docs/agent-notes/accessibility-audit.md`.
@MainActor
final class AccessibilityAuditUITests: XCTestCase {
    private static let locales: [String] = {
        let environment = ProcessInfo.processInfo.environment
        let chosen = (environment["AUDIT_LOCALES"] ?? environment["AUDIT_PLAN_LOCALES"])?
            .split(separator: ",").map(String.init)
        return chosen ?? ["en", "pt-BR"]
    }()

    /// `TEST_RUNNER_AUDIT_SETTINGS=none` drops Increase Contrast and Reduce Motion, to compare.
    private static let settings: [String] = ProcessInfo.processInfo.environment["AUDIT_SETTINGS"] == "none"
        ? [] : ["-uiIncreaseContrast", "-uiReduceMotion"]

    /// `TEST_RUNNER_AUDIT_WALKS=records,clients` runs some of the walks (onboarding, workspace, clients, records).
    private static let walks: Set<String> = {
        let chosen = ProcessInfo.processInfo.environment["AUDIT_WALKS"]?.split(separator: ",").map(String.init)
        return Set(chosen ?? ["onboarding", "workspace", "clients", "records"])
    }()

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
            let size = largestText
            if Self.walks.contains("onboarding") { try walkOnboarding(locale: locale, largestText: size, tag: tag) }
            if Self.walks.contains("workspace") { try walkWorkspace(locale: locale, largestText: size, tag: tag) }
            if Self.walks.contains("clients") {
                try walkClientsAndCalendar(locale: locale, largestText: size, tag: tag)
            }
            if Self.walks.contains("records") { try walkRecordHistory(locale: locale, largestText: size, tag: tag) }
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
        // In pt-BR at AX5 the win-back card fills the screen and the list (a lazy collection) drops the rows below
        // it from the tree while the audit runs: scroll until one is there again.
        for _ in 0..<4 where !app.clientRows.firstMatch.exists { app.swipeUp() }
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

    /// Every audit type except pixel-sampled contrast. The contrast audit flagged ink #272522 on white (15:1) and
    /// every other body text on the record history, Privacy and Plan, with Increase Contrast on and off alike
    /// (2026-10-10, 187 issues on screens that measure well above 4.5:1): it is not usable on this app's text, so
    /// contrast stays measured exactly, pair by pair, light, dark and Increase Contrast, by `PaletteContrastTests`
    /// (CLAUDE.md section 5).
    /// Also ignored, each a system behavior or a documented choice:
    /// - issues with no element on screen, or on an element the screen does not fully show (under the tab bar, past the
    ///   bottom edge): the next swipe audits it in place;
    /// - navigation-bar titles and toolbar buttons (system-drawn; Liquid Glass bars cap their own text size);
    /// - text fields and search fields reported as clipped: they scroll their text horizontally;
    /// - the insight tiles' numbers, capped at AX2 on purpose so a 30 pt figure fits its tile (`InsightTile`);
    /// - the parts of the logo (`BrandLockup`, one element read as the image "Bello Hub"): a logo keeps its size;
    /// - "partially unsupported" Dynamic Type on the last row of each Services section (`services.addRow`,
    ///   `services.productsLink`): their text is `Typography.bodyStrong`/`meta` like every other row and the rows grow
    ///   with the text (56 pt at the default size, 62.7 pt at AX5 in the same run); the check flags only these two.
    /// - "partially unsupported" Dynamic Type on the lower cards of an onboarding step (S12: Other, Barber, Massage on
    ///   the profession step in en and pt-BR at the default size). The audit enlarges the text in place: the title
    ///   grows and pushes the grid under the pinned Continue bar, so the audit cannot see those cards grow. They are
    ///   `ChoiceCard`s like the ones above them, and the same step passes the AX5 run (one column) without exception.
    ///   Only Dynamic Type issues within `pinnedBarReach` of a pinned Continue bar are skipped.
    private static let partialDynamicTypeExceptions = ["services.addRow", "services.productsLink"]
    private static let pinnedBarReach: CGFloat = 260
    private static let auditTypes: XCUIAccessibilityAuditType = .all.subtracting(.contrast)

    private func audit(_ app: XCUIApplication, _ screen: String) throws {
        let window = app.windows.firstMatch.frame
        let tabBar = app.tabBars.firstMatch
        let visibleBottom = tabBar.exists ? tabBar.frame.minY : window.maxY
        let navigationBar = app.navigationBars.firstMatch
        let bar = navigationBar.exists ? navigationBar.frame : .zero
        let logo = app.images["Bello Hub"].firstMatch
        let logoFrame = logo.exists ? logo.frame.insetBy(dx: -2, dy: -2) : .zero
        let exceptionFrames = Self.partialDynamicTypeExceptions.compactMap { identifier -> CGRect? in
            let element = app.descendants(matching: .any).matching(identifier: identifier).firstMatch
            return element.exists ? element.frame.insetBy(dx: -2, dy: -2) : nil
        }
        let continueBar = app.buttons.matching(NSPredicate(format: "identifier ENDSWITH '.continueButton'")).firstMatch
        let pinnedBarTop = continueBar.exists ? continueBar.frame.minY : nil
        try app.performAccessibilityAudit(for: Self.auditTypes) { issue in
            guard let element = issue.element, !(element.label.isEmpty && element.frame == .zero) else { return true }
            let frame = element.frame
            if frame.minY < window.minY || frame.maxY > visibleBottom { return true }
            if !logoFrame.isEmpty, logoFrame.contains(frame) { return true }
            if issue.auditType == .dynamicType, exceptionFrames.contains(where: { $0.contains(frame) }) { return true }
            if issue.auditType == .dynamicType, let pinnedBarTop, frame.maxY > pinnedBarTop - Self.pinnedBarReach {
                return true
            }
            if !bar.isEmpty, bar.contains(CGPoint(x: frame.midX, y: frame.midY)) { return true }
            let kind = element.elementType
            if issue.auditType == .textClipped, kind == .textField || kind == .searchField { return true }
            if issue.auditType == .dynamicType, kind == .staticText, !element.label.isEmpty,
               element.label.allSatisfy(\.isNumber) {
                return true
            }
            let names = [element.identifier, element.label].filter { !$0.isEmpty }
            XCTFail(
                "[\(screen)] \(issue.compactDescription): \(names.joined(separator: " | ")) \(frame) -- "
                    + issue.detailedDescription
            )
            return true
        }
    }
}
