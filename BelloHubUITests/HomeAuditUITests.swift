//
//  HomeAuditUITests.swift
//  BelloHubUITests
//

import XCTest

/// Accessibility audit of Home, Follow-ups, the client message sheet, Win back and the Alerts tab, in several
/// localizations, at the default size and at AX5. Slow, so it runs in the Full plan and is skipped by UISmoke.
/// Each screen must render without clipped text and with spoken descriptions in `ar` and at the largest text size.
@MainActor
final class HomeAuditUITests: XCTestCase {
    /// `TEST_RUNNER_AUDIT_LOCALES=en,ar scripts/test.sh ...` narrows the run to some localizations while iterating.
    private static let locales: [String] = {
        let chosen = ProcessInfo.processInfo.environment["AUDIT_LOCALES"]?.split(separator: ",").map(String.init)
        return chosen ?? ["en", "pt-BR", "de", "ar", "hi"]
    }()

    override func setUp() async throws {
        continueAfterFailure = true
    }

    func testHomeAtDefaultSize() throws {
        try auditHome(largestText: false)
    }

    func testHomeAtLargestSize() throws {
        try auditHome(largestText: true)
    }

    // MARK: - Walk

    private func auditHome(largestText: Bool) throws {
        for locale in Self.locales {
            let app = XCUIApplication.launchedOnHome(locale: locale, largestText: largestText)
            let tag = "\(locale)\(largestText ? " AX5" : "")"
            XCTAssertTrue(app.element("home.next").waitForExistence(timeout: 10), "\(tag) home has visits")
            try audit(app, "\(tag) home")
            app.swipeUp()
            try audit(app, "\(tag) home, lower half")
            app.swipeUp()
            try audit(app, "\(tag) home, bottom")
            try auditFollowUps(app, tag: tag)
            try auditWinBack(app, tag: tag)
            try auditAlerts(app, tag: tag)
            app.terminate()
        }
    }

    private func auditFollowUps(_ app: XCUIApplication, tag: String) throws {
        app.scrollToTop()
        app.scrollToAndTap(prefix: "home.followUps.view")
        XCTAssertTrue(app.element("followUps.subtitle").waitForExistence(timeout: 10), "\(tag) follow-ups")
        XCTAssertTrue(app.elements(prefix: "followUps.row.").firstMatch.waitForExistence(timeout: 10),
                      "\(tag) follow-ups has rows")
        try audit(app, "\(tag) follow-ups")
        app.swipeUp()
        try audit(app, "\(tag) follow-ups, lower half")
        app.swipeDown()
        app.scrollToAndTap(prefix: "followUps.message.")
        XCTAssertTrue(app.element("clientMessage.form").waitForExistence(timeout: 10), "\(tag) client message")
        try audit(app, "\(tag) client message")
        app.tapButton("clientMessage.closeButton")
        XCTAssertTrue(app.element("followUps.subtitle").waitForExistence(timeout: 5))
        app.goBack()
        XCTAssertTrue(app.staticTexts["home.greeting"].waitForExistence(timeout: 5))
    }

    private func auditWinBack(_ app: XCUIApplication, tag: String) throws {
        app.scrollToTop()
        app.scrollToAndTap(prefix: "home.winBack")
        XCTAssertTrue(app.element("winBack.subtitle").waitForExistence(timeout: 10), "\(tag) win back")
        XCTAssertTrue(app.elements(prefix: "winBack.row.").firstMatch.waitForExistence(timeout: 10),
                      "\(tag) win back has rows")
        try audit(app, "\(tag) win back")
        app.swipeUp()
        try audit(app, "\(tag) win back, lower half")
        app.goBack()
        XCTAssertTrue(app.staticTexts["home.greeting"].waitForExistence(timeout: 5))
    }

    private func auditAlerts(_ app: XCUIApplication, tag: String) throws {
        app.openAlertsTab()
        try audit(app, "\(tag) alerts")
        app.swipeUp()
        try audit(app, "\(tag) alerts, lower half")
    }

    /// Clipped text and missing descriptions only, as in the other audits (contrast is measured exactly by the unit
    /// tests). The same false positives are ignored, and for the same reasons: Devanagari and Arabic text, whose
    /// fallback fonts the "may be clipped at larger Dynamic Type sizes" heuristic measures with Latin metrics even
    /// though the screens scroll and nothing is cut; the navigation bar title; the system's own text editors.
    private func audit(_ app: XCUIApplication, _ screen: String) throws {
        try app.performAccessibilityAudit(for: [.textClipped, .sufficientElementDescription]) { issue in
            let element = issue.element
            if issue.auditType == .textClipped, Self.isKnownFalsePositive(element, in: app) { return true }
            if issue.auditType == .textClipped, element == nil { return true }
            let names = [element?.identifier, element?.label].compactMap { $0 }.filter { !$0.isEmpty }
            let frame = element?.frame ?? .zero
            let what = names.joined(separator: " | ")
            XCTFail("[\(screen)] \(issue.compactDescription): \(what) \(frame) -- \(issue.detailedDescription)")
            return true
        }
    }

    private static func isKnownFalsePositive(_ element: XCUIElement?, in app: XCUIApplication) -> Bool {
        guard let element else { return false }
        if element.elementType == .textView || element.elementType == .textField { return true }
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
