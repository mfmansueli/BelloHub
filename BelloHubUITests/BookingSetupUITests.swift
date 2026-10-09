//
//  BookingSetupUITests.swift
//  BelloHubUITests
//

import XCTest

/// Her booking setup, end to end: weekly hours with a break, the booking page paused with a return date, and the share
/// link screen with its address and QR code. Stage S5, screens 6.5, 6.7 and 6.8.
@MainActor
final class BookingSetupUITests: XCTestCase {
    override func setUp() async throws {
        continueAfterFailure = false
    }

    func testHoursWithABreakThenPauseThenShareLink() {
        let app = XCUIApplication.launchedOnBookingSetup()

        // The More rows say where she stands: a page that takes bookings and the suggested week.
        app.tab(4).tap()
        XCTAssertTrue(app.buttons["more.bookingPageRow"].waitForExistence(timeout: 8))
        XCTAssertTrue(waitForLabel(app.buttons["more.bookingPageRow"], containing: "Taking bookings"))
        XCTAssertTrue(waitForLabel(app.buttons["more.availabilityRow"], containing: "Mon to Fri"))

        // Hours: open Saturday, add a lunch break.
        app.tapButton("more.availabilityRow")
        app.flipSwitch("availability.dayToggle.7")
        XCTAssertTrue(app.buttons["availability.day.7"].label.contains("9:00"), app.buttons["availability.day.7"].label)
        XCTAssertTrue(app.scrollUntilExists(app.buttons["availability.addBreakButton"]))
        app.tapButton("availability.addBreakButton")
        app.type("Lunch", intoField: "availability.breakSheet.nameField")
        app.tapButton("availability.breakSheet.saveButton")
        let lunch = app.buttons["availability.break.0"]
        XCTAssertTrue(lunch.waitForExistence(timeout: 5))
        XCTAssertTrue(lunch.label.contains("Lunch") && lunch.label.contains("every day"), lunch.label)

        // The row on More follows her change: Monday to Friday plus Saturday is no longer one run of the same hours.
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.buttons["more.availabilityRow"].waitForExistence(timeout: 5))
        XCTAssertTrue(waitForLabel(app.buttons["more.availabilityRow"], containing: "Mon to Sat"))

        // Pause the page with a return date.
        app.tapButton("more.bookingPageRow")
        app.flipSwitch("bookingSettings.acceptingSwitch", opens: app.switches["bookingSettings.pauseSheet.dateSwitch"])
        app.flipSwitch("bookingSettings.pauseSheet.dateSwitch")
        XCTAssertTrue(app.element("bookingSettings.pauseSheet.datePicker").waitForExistence(timeout: 5))
        app.tapButton("bookingSettings.pauseSheet.confirmButton")
        XCTAssertTrue(app.element("bookingSettings.returnDatePicker").waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["bookingSettings.resumeButton"].exists)

        // The link screen: pick the suggested address, save it, see the link and its QR code.
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.tab(4).tap()
        XCTAssertTrue(waitForLabel(app.buttons["more.bookingPageRow"], containing: "Paused until"))
        app.tapButton("more.bookingPageRow")
        XCTAssertTrue(app.scrollUntilExists(app.buttons["bookingSettings.shareRow"]))
        app.tapButton("bookingSettings.shareRow")
        app.tapButton("shareLink.suggestion.maria-silva")
        XCTAssertTrue(app.buttons["shareLink.saveAddressButton"].waitForExistence(timeout: 5))
        let save = app.buttons["shareLink.saveAddressButton"]
        XCTAssertTrue(waitUntilEnabled(save), "a valid address can be saved before it can be checked")
        save.tap()
        XCTAssertTrue(app.element("shareLink.qr").waitForExistence(timeout: 5))
        XCTAssertEqual(app.element("shareLink.linkText").label, "bellohub.app/maria-silva")
        XCTAssertTrue(app.element("shareLink.notOnline").exists, "the screen says the page is not online yet")
        XCTAssertTrue(app.buttons["shareLink.shareButton"].exists && app.buttons["shareLink.copyButton"].exists)
    }

    func testPoliciesAndQuickReplies() {
        let app = XCUIApplication.launchedOnBookingSetup()
        app.openMoreRow("more.bookingPageRow")
        XCTAssertTrue(app.scrollUntilExists(app.buttons["bookingSettings.cancelRow"]))

        // Cancellations: a longer free window changes what clients read.
        app.tapButton("bookingSettings.cancelRow")
        app.tapButton("cancelPolicy.window.48")
        XCTAssertTrue(app.scrollUntilExists(app.element("cancelPolicy.ruleText")))
        XCTAssertTrue(app.element("cancelPolicy.ruleText").label.contains("48"),
            app.element("cancelPolicy.ruleText").label)
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(waitForLabel(app.buttons["bookingSettings.cancelRow"], containing: "48"))

        // No-show protection: switch it off and the sentence goes away.
        app.tapButton("bookingSettings.noShowRow")
        XCTAssertTrue(app.element("noShowPolicy.ruleText").waitForExistence(timeout: 5))
        app.flipSwitch("noShowPolicy.masterSwitch")
        XCTAssertTrue(app.element("noShowPolicy.offNote").waitForExistence(timeout: 5))
        XCTAssertTrue(app.waitUntilGone(app.element("noShowPolicy.ruleText")))

        // Quick replies: edit the first one and see it saved.
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.tapButton("more.quickRepliesRow")
        let first = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'quickReplies.row.'")).firstMatch
        XCTAssertTrue(first.waitForExistence(timeout: 8))
        first.tap()
        XCTAssertTrue(app.element("quickReplyEditor.messageField").waitForExistence(timeout: 5))
        app.tapButton("quickReplyEditor.word.link")
        app.tapButton("quickReplyEditor.saveButton")
        XCTAssertTrue(app.buttons["quickReplyEditor.saveButton"].label.contains("Saved"))
    }

    // MARK: - Helpers

    private func waitForLabel(_ element: XCUIElement, containing text: String, timeout: TimeInterval = 8) -> Bool {
        let matches = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label CONTAINS %@", text), object: element
        )
        return XCTWaiter().wait(for: [matches], timeout: timeout) == .completed
    }

    private func waitUntilEnabled(_ element: XCUIElement, timeout: TimeInterval = 5) -> Bool {
        let enabled = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isEnabled == true"), object: element)
        return XCTWaiter().wait(for: [enabled], timeout: timeout) == .completed
    }
}
