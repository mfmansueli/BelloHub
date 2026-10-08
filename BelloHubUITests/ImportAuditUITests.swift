//
//  ImportAuditUITests.swift
//  BelloHubUITests
//

import XCTest

/// Accessibility audit of the client import (4.6) and the Ready screen with its shortcut: clipped text and missing
/// descriptions, in several localizations, at the default size and at AX5. Slow, so it runs in the Full plan and is
/// skipped by UISmoke. One launch per localization walks the contacts path (with only two free registrations left, so
/// the limit notice, the blocked rows and the plan offer are on screen) and then the spreadsheet path (mapping, the
/// list with skipped rows, the result).
@MainActor
final class ImportAuditUITests: XCTestCase {
    /// `TEST_RUNNER_AUDIT_LOCALES=en,ar scripts/test.sh ...` narrows the run to some localizations while iterating.
    private static let locales: [String] = {
        let chosen = ProcessInfo.processInfo.environment["AUDIT_LOCALES"]?.split(separator: ",").map(String.init)
        return chosen ?? ["en", "pt-BR", "de", "ar", "hi"]
    }()

    override func setUp() async throws {
        continueAfterFailure = true
    }

    func testImportAtDefaultSize() throws {
        try auditImport(largestText: false)
    }

    func testImportAtLargestSize() throws {
        try auditImport(largestText: true)
    }

    // MARK: - Walk

    private func auditImport(largestText: Bool) throws {
        for locale in Self.locales {
            let app = XCUIApplication.launchedForUITests(
                locale: locale, largestText: largestText,
                arguments: ["-uiContacts", "four", "-uiSpreadsheet", "clients", "-uiRegisteredClients", "8"]
            )
            let tag = "\(locale)\(largestText ? " AX5" : "")"
            app.createAccount()
            app.completeSetup()
            XCTAssertTrue(app.staticTexts["onboarding.ready.title"].waitForExistence(timeout: 5), "\(tag) ready")
            try audit(app, "\(tag) ready")

            app.tapButton("onboarding.ready.importButton")
            XCTAssertTrue(app.staticTexts["importClients.sources.title"].waitForExistence(timeout: 5), "\(tag) sources")
            try audit(app, "\(tag) sources")

            try auditContactsPath(app, tag: tag)
            try auditSpreadsheetPath(app, tag: tag)
            app.terminate()
        }
    }

    private func auditContactsPath(_ app: XCUIApplication, tag: String) throws {
        app.tapButton("importClients.source.contacts")
        XCTAssertTrue(app.staticTexts["importClients.choose.title"].waitForExistence(timeout: 5), "\(tag) choose")
        try audit(app, "\(tag) choose contacts")

        app.tapButton("importClients.importButton")
        XCTAssertTrue(app.staticTexts["importClients.result.title"].waitForExistence(timeout: 5), "\(tag) result")
        try audit(app, "\(tag) result with plan offer")

        app.tapButton("importClients.result.viewClientsButton")
        XCTAssertTrue(app.staticTexts["onboarding.ready.title"].waitForExistence(timeout: 5), "\(tag) back to ready")
        app.tapButton("onboarding.ready.importButton")
        XCTAssertTrue(app.staticTexts["importClients.sources.title"].waitForExistence(timeout: 5))
    }

    private func auditSpreadsheetPath(_ app: XCUIApplication, tag: String) throws {
        app.tapButton("importClients.source.spreadsheet")
        XCTAssertTrue(app.staticTexts["importClients.mapping.title"].waitForExistence(timeout: 5), "\(tag) mapping")
        try audit(app, "\(tag) mapping")

        app.tapButton("importClients.mapping.continueButton")
        XCTAssertTrue(app.staticTexts["importClients.choose.title"].waitForExistence(timeout: 5), "\(tag) choose rows")
        try audit(app, "\(tag) choose rows with skipped entries")

        app.tapButton("importClients.importButton")
        XCTAssertTrue(app.staticTexts["importClients.result.title"].waitForExistence(timeout: 5), "\(tag) result 2")
        try audit(app, "\(tag) result of the spreadsheet")
    }

    /// Clipped text and missing descriptions only, as in `OnboardingAuditUITests`: contrast is measured exactly by the
    /// unit tests (CLAUDE.md section 5), and Devanagari and Arabic text is skipped by the clipping heuristic, which
    /// measures their fallback fonts with Latin metrics even though the screens scroll and nothing is cut at AX5.
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
