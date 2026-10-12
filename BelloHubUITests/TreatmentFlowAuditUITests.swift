//
//  TreatmentFlowAuditUITests.swift
//  BelloHubUITests
//

import XCTest

/// Accessibility audit of the treatment flow (register, listening, organizing, review, form, saved, next session,
/// photos, camera), in several localizations, at the default size and at AX5. Slow, so it runs in the Full plan and is
/// skipped by UISmoke.
@MainActor
final class TreatmentFlowAuditUITests: XCTestCase {
    /// `TEST_RUNNER_AUDIT_LOCALES=en,ar` narrows the run to some localizations while iterating.
    private static let locales: [String] = {
        let chosen = ProcessInfo.processInfo.environment["AUDIT_LOCALES"]?.split(separator: ",").map(String.init)
        return chosen ?? ["en", "pt-BR", "de", "ar", "hi"]
    }()

    override func setUp() async throws {
        continueAfterFailure = true
    }

    func testFlowAtDefaultSize() throws {
        try auditFlow(largestText: false)
    }

    func testFlowAtLargestSize() throws {
        try auditFlow(largestText: true)
    }

    // MARK: - Walk

    private func auditFlow(largestText: Bool) throws {
        for locale in Self.locales {
            let tag = "\(locale)\(largestText ? " AX5" : "")"
            try auditVoicePath(locale: locale, largestText: largestText, tag: tag)
            try auditManualPath(locale: locale, largestText: largestText, tag: tag)
        }
    }

    private func auditVoicePath(locale: String, largestText: Bool, tag: String) throws {
        let app = XCUIApplication.launchedOnTreatmentFlow(voice: true, locale: locale, largestText: largestText)
        let voiceButton = app.buttons["treatmentFlow.register.voiceButton"]
        XCTAssertTrue(voiceButton.waitForExistence(timeout: 30), "\(tag) form with voice")
        try audit(app, "\(tag) form with voice")
        app.tapButton("treatmentFlow.register.voiceButton")
        XCTAssertTrue(app.element("treatmentFlow.listening").waitForExistence(timeout: 10), "\(tag) listening")
        try audit(app, "\(tag) listening")
        app.tapButton("treatmentFlow.listening.finishButton")
        XCTAssertTrue(app.element("treatmentFlow.review").waitForExistence(timeout: 20), "\(tag) review")
        try audit(app, "\(tag) review")
        app.terminate()
    }

    private func auditManualPath(locale: String, largestText: Bool, tag: String) throws {
        let app = XCUIApplication.launchedOnTreatmentFlow(locale: locale, largestText: largestText)
        XCTAssertTrue(app.element("treatmentFlow.form").waitForExistence(timeout: 30), "\(tag) form")
        try audit(app, "\(tag) form")
        app.swipeUp()
        try audit(app, "\(tag) form, lower half")
        app.tapButton("treatmentFlow.form.saveButton")
        XCTAssertTrue(app.element("treatmentFlow.form.emptyError").waitForExistence(timeout: 5), "\(tag) form error")
        try audit(app, "\(tag) form with the error")
        app.swipeDown()
        app.swipeDown()
        app.tapButton("treatmentFlow.photos.takeButton")
        app.tapButton("visitForm.photos.take.before")
        XCTAssertTrue(app.buttons["treatmentFlow.camera.captureButton"].waitForExistence(timeout: 15), "\(tag) camera")
        try audit(app, "\(tag) camera")
        app.tapButton("treatmentFlow.camera.captureButton")
        XCTAssertTrue(app.element("treatmentFlow.camera.reviewScreen").waitForExistence(timeout: 10), "\(tag) shot")
        try audit(app, "\(tag) review photo")
        app.tapButton("treatmentFlow.camera.saveButton")
        XCTAssertTrue(app.element(withPrefix: "treatmentFlow.photos.row.").waitForExistence(timeout: 20))
        try audit(app, "\(tag) form with a photo and a draft")
        app.typeNotes("Skin a little sensitive.")
        app.tapButton("treatmentFlow.form.saveButton")
        XCTAssertTrue(app.element("treatmentFlow.saved").waitForExistence(timeout: 15), "\(tag) saved")
        try audit(app, "\(tag) saved")
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
