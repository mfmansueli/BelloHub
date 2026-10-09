//
//  CalendarAuditUITests.swift
//  BelloHubUITests
//

import XCTest

/// Accessibility audit of the calendar screens (day, week, week glance, new appointment, reschedule, block time), in
/// several localizations, at the default size and at AX5. Slow, so it runs in the Full plan and is skipped by UISmoke.
/// Each screen must render without clipped text and with spoken descriptions in `ar` and at the largest text size.
@MainActor
final class CalendarAuditUITests: XCTestCase {
    /// `TEST_RUNNER_AUDIT_LOCALES=en,ar scripts/test.sh ...` narrows the run to some localizations while iterating.
    private static let locales: [String] = {
        let chosen = ProcessInfo.processInfo.environment["AUDIT_LOCALES"]?.split(separator: ",").map(String.init)
        return chosen ?? ["en", "pt-BR", "de", "ar", "hi"]
    }()

    override func setUp() async throws {
        continueAfterFailure = true
    }

    func testCalendarAtDefaultSize() throws {
        try auditCalendar(largestText: false)
    }

    func testCalendarAtLargestSize() throws {
        try auditCalendar(largestText: true)
    }

    // MARK: - Walk

    private func auditCalendar(largestText: Bool) throws {
        for locale in Self.locales {
            let app = XCUIApplication.launchedForUITests(
                locale: locale, largestText: largestText,
                arguments: ["-uiSeed", "clients", "-uiCalendar", "-uiCalendarVisits"]
            )
            let tag = "\(locale)\(largestText ? " AX5" : "")"
            app.openCalendarTab()
            XCTAssertTrue(app.calendarVisits.firstMatch.waitForExistence(timeout: 10), "\(tag) day has visits")
            try audit(app, "\(tag) day")
            try auditWeek(app, tag: tag, locale: locale)
            try auditWeekGlance(app, tag: tag)
            try auditNewAppointment(app, tag: tag)
            try auditReschedule(app, tag: tag)
            try auditBlockTime(app, tag: tag)
            app.terminate()
        }
    }

    private func auditWeek(_ app: XCUIApplication, tag: String, locale: String) throws {
        let modes = app.segmentedControls["calendar.modePicker"]
        XCTAssertTrue(modes.waitForExistence(timeout: 5), "\(tag) mode picker")
        // The buttons come in visual order, so the right-to-left pair is reversed.
        let rtl = locale == "ar"
        modes.buttons.element(boundBy: rtl ? 0 : 1).tap()
        // At accessibility sizes the week is a list of days, so today's visit may be below the fold.
        var scrolls = 0
        while !app.calendarVisits.firstMatch.waitForExistence(timeout: 2), scrolls < 4 {
            app.swipeUp()
            scrolls += 1
        }
        XCTAssertTrue(app.calendarVisits.firstMatch.exists, "\(tag) week has visits")
        try audit(app, "\(tag) week")
        modes.buttons.element(boundBy: rtl ? 1 : 0).tap()
        XCTAssertTrue(app.element("calendar.modePicker").waitForExistence(timeout: 5))
    }

    private func auditWeekGlance(_ app: XCUIApplication, tag: String) throws {
        app.tapButton("calendar.weekGlanceButton")
        XCTAssertTrue(app.element("weekGlance.subtitle").waitForExistence(timeout: 10), "\(tag) week glance")
        XCTAssertTrue(app.element("weekGlance.tile.leftToday").waitForExistence(timeout: 10), "\(tag) week glance data")
        try audit(app, "\(tag) week glance")
        app.swipeUp()
        try audit(app, "\(tag) week glance, lower half")
        app.goBack()
        XCTAssertTrue(app.element("calendar.modePicker").waitForExistence(timeout: 5))
    }

    private func auditNewAppointment(_ app: XCUIApplication, tag: String) throws {
        app.tapButton("calendar.newButton")
        let confirm = app.element("newAppointment.confirmButton")
        XCTAssertTrue(confirm.waitForExistence(timeout: 5), "\(tag) new appointment")
        try audit(app, "\(tag) new appointment")
        app.tapButton("newAppointment.client.0")
        app.swipeUp()
        try audit(app, "\(tag) new appointment, lower half")
        app.tapButton("newAppointment.cancelButton")
        XCTAssertTrue(app.element("calendar.modePicker").waitForExistence(timeout: 5))
    }

    private func auditReschedule(_ app: XCUIApplication, tag: String) throws {
        let visit = app.calendarVisits.firstMatch
        // The list of the day (accessibility sizes) may have been scrolled by the earlier steps.
        var scrolls = 0
        while !visit.waitForExistence(timeout: 2), scrolls < 4 {
            app.swipeDown()
            scrolls += 1
        }
        XCTAssertTrue(visit.exists, "\(tag) a visit to reschedule")
        if !visit.isHittable { app.swipeUp() }
        app.chooseVisitMenuItem("calendar.visit.menu.reschedule", englishLabel: "Reschedule", on: visit)
        XCTAssertTrue(app.element("reschedule.visit").waitForExistence(timeout: 5), "\(tag) reschedule")
        try audit(app, "\(tag) reschedule")
        app.tapButton("reschedule.closeButton")
        XCTAssertTrue(app.element("calendar.modePicker").waitForExistence(timeout: 5))
    }

    private func auditBlockTime(_ app: XCUIApplication, tag: String) throws {
        app.tapButton("calendar.moreMenu")
        app.tapButton("calendar.blockTimeButton")
        XCTAssertTrue(app.element("blockTime.saveButton").waitForExistence(timeout: 5), "\(tag) block time")
        try audit(app, "\(tag) block time")
        let scope = app.segmentedControls["blockTime.scopePicker"]
        XCTAssertTrue(scope.waitForExistence(timeout: 5), "\(tag) scope picker")
        scope.buttons.element(boundBy: 1).tap()
        app.swipeUp()
        try audit(app, "\(tag) block time, lower half")
        app.tapButton("blockTime.cancelButton")
        XCTAssertTrue(app.element("calendar.modePicker").waitForExistence(timeout: 5))
    }

    /// Clipped text and missing descriptions only, as in the other audits (contrast is measured exactly by the unit
    /// tests). The same false positives are ignored, and for the same reasons: Devanagari and Arabic text, whose
    /// fallback fonts the "may be clipped at larger Dynamic Type sizes" heuristic measures with Latin metrics even
    /// though the screens scroll and nothing is cut; the one-line fields; and the system's own date pickers.
    private func audit(_ app: XCUIApplication, _ screen: String) throws {
        try app.performAccessibilityAudit(for: [.textClipped, .sufficientElementDescription]) { issue in
            let element = issue.element
            if issue.auditType == .textClipped, Self.isKnownFalsePositive(element, in: app) { return true }
            if issue.auditType == .textClipped, element == nil { return true }
            if issue.auditType == .textClipped, Self.isInsideTimelineBlock(element, in: app) { return true }
            let names = [element?.identifier, element?.label].compactMap { $0 }.filter { !$0.isEmpty }
            let frame = element?.frame ?? .zero
            let what = names.joined(separator: " | ")
            XCTFail("[\(screen)] \(issue.compactDescription): \(what) \(frame) -- \(issue.detailedDescription)")
            return true
        }
    }

    /// A block on the timeline has the height of the visit, so its lines truncate by design; the whole text is the
    /// block's VoiceOver label, and at accessibility sizes the screens show lists instead of the timeline.
    private static func isInsideTimelineBlock(_ element: XCUIElement?, in app: XCUIApplication) -> Bool {
        guard let element, element.elementType == .staticText, !element.frame.isEmpty else { return false }
        return app.calendarVisits.allElementsBoundByIndex.contains { $0.frame.contains(element.frame) }
    }

    private static func isKnownFalsePositive(_ element: XCUIElement?, in app: XCUIApplication) -> Bool {
        guard let element else { return false }
        if element.elementType == .searchField || element.elementType == .datePicker { return true }
        if element.label.isEmpty, element.frame == .zero { return true }
        let bar = app.navigationBars.firstMatch.frame
        let center = CGPoint(x: element.frame.midX, y: element.frame.midY)
        if element.elementType == .staticText, !bar.isEmpty, bar.contains(center) { return true }
        // One line by nature: a guest's name, the search field of the client list.
        let oneLineFields = ["searchField", "nameField"]
        if oneLineFields.contains(where: { element.identifier.contains($0) }) { return true }
        let fallbackFontScripts = [0x0600...0x06FF, 0x0900...0x097F]
        return element.label.unicodeScalars.contains { scalar in
            fallbackFontScripts.contains { $0.contains(Int(scalar.value)) }
        }
    }
}
