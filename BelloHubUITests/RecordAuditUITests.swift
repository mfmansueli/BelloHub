//
//  RecordAuditUITests.swift
//  BelloHubUITests
//

import XCTest

/// Accessibility audit of the record screens (history with a locked record, the correction sheet, the incident sheet
/// and its saved state, the export sheet and its ready state, the AI settings), in several localizations, at the
/// default size and at AX5. Slow, so it runs in the Full plan and is skipped by UISmoke.
@MainActor
final class RecordAuditUITests: XCTestCase {
    /// `TEST_RUNNER_AUDIT_LOCALES=en,ar` narrows the run to some localizations while iterating.
    private static let locales: [String] = {
        let chosen = ProcessInfo.processInfo.environment["AUDIT_LOCALES"]?.split(separator: ",").map(String.init)
        return chosen ?? ["en", "pt-BR", "de", "ar", "hi"]
    }()

    override func setUp() async throws {
        continueAfterFailure = true
    }

    func testRecordScreensAtDefaultSize() throws {
        try auditRecords(largestText: false)
    }

    func testRecordScreensAtLargestSize() throws {
        try auditRecords(largestText: true)
    }

    // MARK: - Walk

    private func auditRecords(largestText: Bool) throws {
        for locale in Self.locales {
            let tag = "\(locale)\(largestText ? " AX5" : "")"
            try auditHistory(locale: locale, largestText: largestText, tag: tag)
            try auditSheets(locale: locale, largestText: largestText, tag: tag)
            try auditAISettings(locale: locale, largestText: largestText, tag: tag)
        }
    }

    private func auditHistory(locale: String, largestText: Bool, tag: String) throws {
        let app = XCUIApplication.launchedOnRecordHistory(locale: locale, largestText: largestText)
        XCTAssertTrue(app.element("recordHistory.overview").waitForExistence(timeout: 30), "\(tag) history")
        try audit(app, "\(tag) history")
        app.swipeUp()
        try audit(app, "\(tag) history, lower half")
        app.swipeUp()
        try audit(app, "\(tag) history, photos")

        app.swipeDown()
        app.swipeDown()
        app.tapRow("recordHistory.change.\(XCUIApplication.lockedRecordID)", expecting: "recordHistory.correction.form")
        try audit(app, "\(tag) correction")
        app.tapButton("recordHistory.correction.saveButton")
        XCTAssertTrue(app.element("recordHistory.correction.problem").waitForExistence(timeout: 5))
        try audit(app, "\(tag) correction refused")
        app.terminate()
    }

    private func auditSheets(locale: String, largestText: Bool, tag: String) throws {
        let app = XCUIApplication.launchedOnSeededProfile(locale: locale, largestText: largestText)

        app.chooseRecordMenuItem("clientRecord.menu.incident", expecting: "incident.form")
        try audit(app, "\(tag) incident")
        app.swipeUp()
        try audit(app, "\(tag) incident, lower half")
        app.tapButton("incident.saveButton")
        XCTAssertTrue(app.element("incident.saved").waitForExistence(timeout: 10), "\(tag) incident saved")
        try audit(app, "\(tag) incident saved")
        app.tapButton("incident.doneButton")
        XCTAssertTrue(app.element("incident.saved").waitForNonExistence(timeout: 5))

        app.chooseRecordMenuItem("clientRecord.menu.export", expecting: "exportRecord.form")
        try audit(app, "\(tag) export")
        app.swipeUp()
        try audit(app, "\(tag) export, lower half")
        app.tapButton("exportRecord.exportButton")
        XCTAssertTrue(app.element("exportRecord.ready").waitForExistence(timeout: 20), "\(tag) export ready")
        try audit(app, "\(tag) export ready")
        app.tapButton("exportRecord.backButton")
        app.terminate()
    }

    private func auditAISettings(locale: String, largestText: Bool, tag: String) throws {
        let app = XCUIApplication.launchedOnAISettings(locale: locale, largestText: largestText)
        XCTAssertTrue(app.element("aiSettings.screen").waitForExistence(timeout: 30), "\(tag) AI settings")
        try audit(app, "\(tag) AI settings")
        app.swipeUp()
        try audit(app, "\(tag) AI settings, lower half")
        app.swipeUp()
        try audit(app, "\(tag) AI settings, preferences")
        app.terminate()
    }

    // MARK: - Audit

    /// The same false positives as the other audits: Devanagari and Arabic text, which the "may be clipped" heuristic
    /// measures with Latin metrics, the system's own navigation title, and nodes with neither label nor frame.
    private func audit(_ app: XCUIApplication, _ screen: String) throws {
        try app.performAccessibilityAudit(for: [.textClipped, .sufficientElementDescription]) { issue in
            let element = issue.element
            if issue.auditType == .textClipped, Self.isKnownFalsePositive(element, in: app) { return true }
            let names = [element?.identifier, element?.label].compactMap { $0 }.filter { !$0.isEmpty }
            let frame = element?.frame ?? .zero
            XCTFail(
                "[\(screen)] \(issue.compactDescription): \(names.joined(separator: " | ")) \(frame) -- "
                    + issue.detailedDescription
            )
            return true
        }
    }

    private static func isKnownFalsePositive(_ element: XCUIElement?, in app: XCUIApplication) -> Bool {
        guard let element else { return true }
        if element.label.isEmpty, element.frame == .zero { return true }
        let bar = app.navigationBars.firstMatch.frame
        let center = CGPoint(x: element.frame.midX, y: element.frame.midY)
        if element.elementType == .staticText, !bar.isEmpty, bar.contains(center) { return true }
        let fallbackFontScripts = [0x0600...0x06FF, 0x0900...0x097F]
        return element.label.unicodeScalars.contains { scalar in
            fallbackFontScripts.contains { $0.contains(Int(scalar.value)) }
        }
    }
}
