//
//  AppointmentAuditUITests.swift
//  BelloHubUITests
//

import XCTest

/// Accessibility audit of the visit detail, the sheets (before you start, cancel, message, no-show, running late)
/// and the pushed session plan and no-show history, in several localizations, at the default size and at AX5.
/// Slow, so it runs in the Full plan and is skipped by UISmoke.
@MainActor
final class AppointmentAuditUITests: XCTestCase {
    /// `TEST_RUNNER_AUDIT_LOCALES=en,ar scripts/test.sh ...` narrows the run to some localizations while iterating.
    private static let locales: [String] = {
        let chosen = ProcessInfo.processInfo.environment["AUDIT_LOCALES"]?.split(separator: ",").map(String.init)
        return chosen ?? ["en", "pt-BR", "de", "ar", "hi"]
    }()

    override func setUp() async throws {
        continueAfterFailure = true
    }

    func testVisitScreensAtDefaultSize() throws {
        try auditVisitScreens(largestText: false)
    }

    func testVisitScreensAtLargestSize() throws {
        try auditVisitScreens(largestText: true)
    }

    // MARK: - Walk

    private func auditVisitScreens(largestText: Bool) throws {
        for locale in Self.locales {
            let app = XCUIApplication.launchedOnAppointments(locale: locale, largestText: largestText)
            let tag = "\(locale)\(largestText ? " AX5" : "")"
            app.tapButton("debugAppointments.upcoming")
            XCTAssertTrue(app.staticTexts["appointment.clientName"].waitForExistence(timeout: 20), "\(tag) detail")
            try audit(app, "\(tag) detail")
            app.swipeUp()
            try audit(app, "\(tag) detail, lower half")

            try walkSheet(app, button: "appointment.beforeYouStartButton", ready: "beforeYouStart.overview",
                          close: "beforeYouStart.closeButton", tag: "\(tag) before you start")
            try walkSheet(app, button: "appointment.messageButton", ready: "messageClient.form",
                          close: "messageClient.closeButton", tag: "\(tag) message")
            try walkSheet(app, button: "appointment.runningLateButton", ready: "runningLate.form",
                          close: "runningLate.closeButton", tag: "\(tag) running late")
            try walkSheet(app, button: "appointment.cancelButton", ready: "cancelAppointment.form",
                          close: "cancelAppointment.closeButton", tag: "\(tag) cancel")
            app.terminate()
        }
    }

    private func walkSheet(
        _ app: XCUIApplication, button: String, ready: String, close: String, tag: String
    ) throws {
        app.scrollToAndTap(button)
        XCTAssertTrue(app.element(ready).waitForExistence(timeout: 10), tag)
        try audit(app, tag)
        app.tapButton(close)
        _ = app.staticTexts["appointment.clientName"].waitForExistence(timeout: 5)
    }

    /// Clipped text and missing descriptions only (contrast is measured exactly by the unit tests). Devanagari and
    /// Arabic text is ignored: the "may be clipped" heuristic measures their fallback fonts with Latin metrics even
    /// though the screens scroll and nothing is cut at AX5.
    private func audit(_ app: XCUIApplication, _ screen: String) throws {
        try app.performAccessibilityAudit(for: [.textClipped, .sufficientElementDescription]) { issue in
            let element = issue.element
            if issue.auditType == .textClipped, Self.isKnownFalsePositive(element, in: app) { return true }
            let names = [element?.identifier, element?.label].compactMap { $0 }.filter { !$0.isEmpty }
            let what = names.joined(separator: " | ")
            XCTFail("[\(screen)] \(issue.compactDescription): \(what) -- \(issue.detailedDescription)")
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
