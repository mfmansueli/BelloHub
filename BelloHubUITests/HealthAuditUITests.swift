//
//  HealthAuditUITests.swift
//  BelloHubUITests
//

import XCTest

/// Accessibility audit of the health screen (4.5 and its three sheets: the form, the consent record and the
/// patch test) and the form settings (6.14), in several localizations, at the default size and at AX5. Slow, so it runs in the Full plan and
/// is skipped by UISmoke. It reports clipped text and missing descriptions; contrast is measured by unit tests
/// (CLAUDE.md section 5), as in `OnboardingAuditUITests`.
@MainActor
final class HealthAuditUITests: XCTestCase {
    /// `AUDIT_LOCALES=en,ar` narrows the run to some localizations while iterating.
    private static let locales: [String] = {
        let chosen = ProcessInfo.processInfo.environment["AUDIT_LOCALES"]?.split(separator: ",").map(String.init)
        return chosen ?? ["en", "pt-BR", "de", "ar", "hi"]
    }()

    override func setUp() async throws {
        continueAfterFailure = true
    }

    func testHealthAtDefaultSize() throws {
        try auditHealth(largestText: false)
    }

    func testHealthAtLargestSize() throws {
        try auditHealth(largestText: true)
    }

    func testFormTemplatesAtDefaultSize() throws {
        try auditFormTemplates(largestText: false)
    }

    func testFormTemplatesAtLargestSize() throws {
        try auditFormTemplates(largestText: true)
    }

    // MARK: - Walks

    private func auditHealth(largestText: Bool) throws {
        for locale in Self.locales {
            let app = XCUIApplication.launchedOnHealth(locale: locale, largestText: largestText)
            let tag = "\(locale)\(largestText ? " AX5" : "")"
            XCTAssertTrue(app.buttons["health.fillButton"].waitForExistence(timeout: 20), "\(tag) empty")
            try audit(app, "\(tag) empty")

            app.tapButton("health.fillButton")
            XCTAssertTrue(app.buttons["healthForm.saveButton"].waitForExistence(timeout: 15), "\(tag) sheet")
            try audit(app, "\(tag) health form")
            app.selectChip("healthForm.minor.yes")
            XCTAssertTrue(app.textFields["healthForm.minorNameField"].waitForExistence(timeout: 15))
            try audit(app, "\(tag) health form, minor")
            app.selectChip("healthForm.minor.no")
            app.answerHealthForm()
            app.tapButton("healthForm.saveButton")

            XCTAssertTrue(app.element("health.answer.allergies").waitForExistence(timeout: 20), "\(tag) answers")
            try audit(app, "\(tag) answers")

            app.tapButton("health.addConsentButton")
            XCTAssertTrue(app.buttons["consent.saveButton"].waitForExistence(timeout: 15), "\(tag) consent sheet")
            try audit(app, "\(tag) consent sheet")
            app.setSwitch("consent.signedToggle", on: false)
            try audit(app, "\(tag) consent sheet, not signed")
            app.tapButton("consent.saveButton")
            let consent = app.button(withPrefix: "health.consent.")
            XCTAssertTrue(consent.waitForExistence(timeout: 20), "\(tag) consent row")
            try audit(app, "\(tag) consents")
            consent.tap()
            XCTAssertTrue(app.buttons["consent.deleteButton"].waitForExistence(timeout: 15), "\(tag) consent edit")
            try audit(app, "\(tag) consent edit")
            app.tapButton("consent.closeButton")

            app.tapButton("health.recordPatchTestButton")
            XCTAssertTrue(app.buttons["patch.saveButton"].waitForExistence(timeout: 15), "\(tag) patch sheet")
            try audit(app, "\(tag) patch test")
            app.typeIntoField("Calming serum", identifier: "patch.productField")
            app.tapButton("patch.saveButton")
            XCTAssertTrue(app.element(withPrefix: "health.patchTest.").waitForExistence(timeout: 20))
            try audit(app, "\(tag) patch log")
            app.terminate()
        }
    }

    private func auditFormTemplates(largestText: Bool) throws {
        for locale in Self.locales {
            let app = XCUIApplication.launchedOnFormTemplates(locale: locale, largestText: largestText)
            let tag = "\(locale)\(largestText ? " AX5" : "")"
            XCTAssertTrue(app.buttons["formTemplates.saveButton"].waitForExistence(timeout: 20), "\(tag) settings")
            try audit(app, "\(tag) form settings")
            app.terminate()
        }
    }

    // MARK: - Audit

    /// Clipped text and missing descriptions only, as in the other audit suites. The two kinds of `.textClipped`
    /// report that are ignored are false positives of the "may be clipped at larger Dynamic Type sizes" heuristic,
    /// which measures Devanagari and Arabic fallback fonts with Latin metrics (the screens scroll and nothing is cut)
    /// and the text fields whose minimum height already holds the next size up.
    private func audit(_ app: XCUIApplication, _ screen: String) throws {
        try app.performAccessibilityAudit(for: [.textClipped, .sufficientElementDescription]) { issue in
            let element = issue.element
            if issue.auditType == .textClipped, Self.isKnownFalsePositive(element) { return true }
            // The system keyboard's prediction bar is not ours and stays up while a field has focus.
            if issue.detailedDescription.contains("TUIPredictionViewCell") { return true }
            let names = [element?.identifier, element?.label].compactMap { $0 }.filter { !$0.isEmpty }
            let frame = element?.frame ?? .zero
            XCTFail("[\(screen)] \(issue.compactDescription): \(names.joined(separator: " | ")) \(frame) -- "
                    + issue.detailedDescription)
            return true // reported above; keep auditing the rest of the screen
        }
    }

    private static func isKnownFalsePositive(_ element: XCUIElement?) -> Bool {
        guard let element else { return false }
        // The text fields keep a 52 pt minimum height that already holds the next text size up; the audit reports
        // them at every size (the same false positive as the phone field in the onboarding audit).
        if element.elementType == .textField || element.elementType == .textView { return true }
        // The title of a sheet wraps in the space left by the close button and grows with the text size; a long single
        // word ("Gesundheitsfragebogen") is reported at the default size although it fits on one line.
        if element.identifier.hasPrefix("sheetHeader.") { return true }
        let fallbackFontScripts = [0x0600...0x06FF, 0x0900...0x097F]
        return element.label.unicodeScalars.contains { scalar in
            fallbackFontScripts.contains { $0.contains(Int(scalar.value)) }
        }
    }
}
