//
//  InboxAuditUITests.swift
//  BelloHubUITests
//

import XCTest

/// Accessibility audit of the inbox screens (2.9 Waitlist, 2.10 BookingRequest, 2.11 RescheduleRequest) and the
/// requests on the Alerts tab, in several localizations, at the default size and at AX5. Slow, so it runs in the Full
/// plan and is skipped by UISmoke. `AUDIT_LOCALES=en,ar` narrows the run while iterating.
@MainActor
final class InboxAuditUITests: XCTestCase {
    private static let locales: [String] = {
        let chosen = ProcessInfo.processInfo.environment["AUDIT_LOCALES"]?.split(separator: ",").map(String.init)
        return chosen ?? ["en", "pt-BR", "de", "ar", "hi"]
    }()

    override func setUp() async throws {
        continueAfterFailure = true
    }

    func testInboxAtDefaultSize() throws {
        try auditInbox(largestText: false)
    }

    func testInboxAtLargestSize() throws {
        try auditInbox(largestText: true)
    }

    // MARK: - Walk

    private func auditInbox(largestText: Bool) throws {
        for locale in Self.locales {
            let app = XCUIApplication.launchedForUITests(
                locale: locale, largestText: largestText, arguments: ["-uiSeed", "onboarded", "-uiInbox", "fixtures"]
            )
            let tag = "\(locale)\(largestText ? " AX5" : "")"
            app.openAlertsTab()
            XCTAssertTrue(app.element("alerts.request.req-ana").waitForExistence(timeout: 10), "\(tag) inbox synced")
            try audit(app, "\(tag) alerts with requests")

            app.scrollToAndTap(prefix: "alerts.request.req-ana.action")
            XCTAssertTrue(app.element("bookingRequest.reason").waitForExistence(timeout: 10), "\(tag) request")
            try auditScrolling(app, "\(tag) booking request")
            app.goBack()

            app.scrollToAndTap(prefix: "alerts.reschedule.rr-camila.action")
            XCTAssertTrue(app.element("rescheduleRequest.requested").waitForExistence(timeout: 10), "\(tag) move")
            try auditScrolling(app, "\(tag) reschedule request")
            app.goBack()

            app.scrollToAndTap(prefix: "alerts.waitlist.action")
            XCTAssertTrue(app.element("waitlist.openTime").waitForExistence(timeout: 10), "\(tag) waitlist")
            try auditScrolling(app, "\(tag) waitlist")
            app.terminate()
        }
    }

    private func auditScrolling(_ app: XCUIApplication, _ screen: String) throws {
        try audit(app, screen)
        app.swipeUp()
        try audit(app, "\(screen), lower half")
        app.swipeDown()
    }

    /// Clipped text and missing descriptions only, with the false positives `HomeAuditUITests` documents: Devanagari
    /// and Arabic fallback fonts measured with Latin metrics, the navigation bar title, the system's text editors.
    private func audit(_ app: XCUIApplication, _ screen: String) throws {
        try app.performAccessibilityAudit(for: [.textClipped, .sufficientElementDescription]) { issue in
            let element = issue.element
            if issue.auditType == .textClipped, Self.isKnownFalsePositive(element, in: app) { return true }
            if issue.auditType == .textClipped, element == nil { return true }
            let names = [element?.identifier, element?.label].compactMap { $0 }.filter { !$0.isEmpty }
            let frame = element?.frame ?? .zero
            XCTFail("[\(screen)] \(issue.compactDescription): \(names.joined(separator: " | ")) \(frame) -- "
                    + issue.detailedDescription)
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
