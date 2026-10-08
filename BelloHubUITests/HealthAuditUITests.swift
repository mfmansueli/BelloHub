//
//  HealthAuditUITests.swift
//  BelloHubUITests
//

import XCTest

/// Accessibility audit of the health and consent screens (4.5 and its three sheets) and the form settings (6.14 and
/// the consent text), in several localizations, at the default size and at AX5. Slow, so it runs in the Full plan and
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
            XCTAssertTrue(app.buttons["health.fillButton"].waitForExistence(timeout: 10), "\(tag) empty")
            try audit(app, "\(tag) empty")

            app.tapButton("health.fillButton")
            XCTAssertTrue(app.buttons["healthForm.saveButton"].waitForExistence(timeout: 5), "\(tag) sheet")
            try audit(app, "\(tag) health form")
            app.tapButton("healthForm.minor.yes")
            XCTAssertTrue(app.textFields["healthForm.minorNameField"].waitForExistence(timeout: 5))
            try audit(app, "\(tag) health form, minor")
            app.tapButton("healthForm.minor.no")
            app.answerHealthFormAndSign()
            app.tapButton("healthForm.saveButton")

            XCTAssertTrue(app.element("health.answer.allergies").waitForExistence(timeout: 10), "\(tag) answers")
            try audit(app, "\(tag) answers")

            let consent = app.button(withPrefix: "health.consent.")
            XCTAssertTrue(consent.waitForExistence(timeout: 5))
            consent.tap()
            XCTAssertTrue(app.element("signedConsent.text").waitForExistence(timeout: 5), "\(tag) signed text")
            try audit(app, "\(tag) signed text")
            app.tapButton("signedConsent.closeButton")

            app.tapButton("health.recordPatchTestButton")
            XCTAssertTrue(app.buttons["patch.saveButton"].waitForExistence(timeout: 5), "\(tag) patch sheet")
            try audit(app, "\(tag) patch test")
            app.type("Calming serum", intoField: "patch.productField")
            app.tapButton("patch.saveButton")
            XCTAssertTrue(app.element(withPrefix: "health.patchTest.").waitForExistence(timeout: 10))
            try audit(app, "\(tag) patch log")
            app.terminate()
        }
    }

    private func auditFormTemplates(largestText: Bool) throws {
        for locale in Self.locales {
            let app = XCUIApplication.launchedOnFormTemplates(locale: locale, largestText: largestText)
            let tag = "\(locale)\(largestText ? " AX5" : "")"
            XCTAssertTrue(app.buttons["formTemplates.saveButton"].waitForExistence(timeout: 10), "\(tag) settings")
            try audit(app, "\(tag) form settings")

            let consent = app.buttons["formTemplates.consent.consent-health"]
            XCTAssertTrue(consent.waitForExistence(timeout: 5))
            consent.tap()
            XCTAssertTrue(app.element("consentPreview.text").waitForExistence(timeout: 5), "\(tag) preview")
            try audit(app, "\(tag) consent text")
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
            let names = [element?.identifier, element?.label].compactMap { $0 }.filter { !$0.isEmpty }
            let frame = element?.frame ?? .zero
            XCTFail("[\(screen)] \(issue.compactDescription): \(names.joined(separator: " | ")) \(frame) -- "
                    + issue.detailedDescription)
            return true // reported above; keep auditing the rest of the screen
        }
    }

    private static func isKnownFalsePositive(_ element: XCUIElement?) -> Bool {
        guard let element else { return false }
        let fallbackFontScripts = [0x0600...0x06FF, 0x0900...0x097F]
        return element.label.unicodeScalars.contains { scalar in
            fallbackFontScripts.contains { $0.contains(Int(scalar.value)) }
        }
    }
}
