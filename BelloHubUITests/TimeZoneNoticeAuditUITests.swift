//
//  TimeZoneNoticeAuditUITests.swift
//  BelloHubUITests
//

import XCTest

/// Accessibility audit of the time-zone notice (tz-mismatch-notice) at AX5, in English and Brazilian Portuguese: the
/// Home card with its three buttons and the Calendar row. Slow, so it runs in the Full plan and is skipped by UISmoke.
@MainActor
final class TimeZoneNoticeAuditUITests: XCTestCase {
    override func setUp() async throws {
        continueAfterFailure = true
    }

    func testNoticeAtLargestSize() throws {
        for locale in ["en", "pt-BR"] {
            let tag = "\(locale) AX5"
            let app = XCUIApplication.launchedWithPhoneZone("Europe/Rome", locale: locale, largestText: true)
            XCTAssertTrue(app.element("home.timeZoneNotice.message").waitForExistence(timeout: 10), "\(tag) card")
            try audit(app, "\(tag) home notice")
            app.swipeUp()
            try audit(app, "\(tag) home notice, buttons")
            app.terminate()

            let calendar = XCUIApplication.launchedWithPhoneZone(
                "Europe/Rome", tab: "calendar", locale: locale, largestText: true
            )
            XCTAssertTrue(calendar.element("calendar.timeZoneNotice").waitForExistence(timeout: 10), "\(tag) row")
            try audit(calendar, "\(tag) calendar row")
            calendar.terminate()
        }
    }

    // MARK: - Helpers

    /// Clipped text and missing descriptions only, as in the other audits (contrast is measured by the unit tests),
    /// with the same known false positives: the navigation bar title and the system's own text editors.
    private func audit(_ app: XCUIApplication, _ screen: String) throws {
        try app.performAccessibilityAudit(for: [.textClipped, .sufficientElementDescription]) { issue in
            let element = issue.element
            if issue.auditType == .textClipped, element == nil { return true }
            if issue.auditType == .textClipped, let element, Self.isInNavigationBar(element, in: app) { return true }
            let names = [element?.identifier, element?.label].compactMap { $0 }.filter { !$0.isEmpty }
            XCTFail("[\(screen)] \(issue.compactDescription): \(names.joined(separator: " | ")) "
                + "\(element?.frame ?? .zero) -- \(issue.detailedDescription)")
            return true
        }
    }

    private static func isInNavigationBar(_ element: XCUIElement, in app: XCUIApplication) -> Bool {
        if element.elementType == .textView || element.elementType == .textField { return true }
        if element.label.isEmpty, element.frame == .zero { return true }
        let bar = app.navigationBars.firstMatch.frame
        let center = CGPoint(x: element.frame.midX, y: element.frame.midY)
        return element.elementType == .staticText && !bar.isEmpty && bar.contains(center)
    }
}
