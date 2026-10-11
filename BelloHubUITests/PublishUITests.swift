//
//  PublishUITests.swift
//  BelloHubUITests
//

import XCTest

/// Putting the booking page online against the in-memory fake server (`-uiOnline fake`, DEBUG only): the link is a
/// preview until she goes online, the More row and the link card follow the real state, and Stop takes it down again.
@MainActor
final class PublishUITests: XCTestCase {
    override func setUp() async throws {
        continueAfterFailure = false
    }

    func testGoOnlineFromShareLinkThenStop() {
        let app = XCUIApplication.launchedForUITests(arguments: ["-uiSeed", "onboarded", "-uiOnline", "fake"])

        // Before an address, nothing is online and the More row says so.
        app.openMoreRow("more.bookingPageRow")
        XCTAssertTrue(app.element("bookingSettings.notOnline").waitForExistence(timeout: 8))
        XCTAssertFalse(app.buttons["bookingSettings.goOnlineButton"].exists, "no address, nothing to publish")
        XCTAssertFalse(app.buttons["bookingSettings.stopButton"].exists)

        // Choose the suggested address: the link is still a preview, with the button that puts her online.
        app.tapButton("bookingSettings.chooseAddressButton")
        app.tapButton("shareLink.suggestion.maria-silva")
        let save = app.buttons["shareLink.saveAddressButton"]
        XCTAssertTrue(waitUntilEnabled(save))
        save.tap()
        XCTAssertTrue(app.element("shareLink.notOnline").waitForExistence(timeout: 5))
        XCTAssertTrue(app.element("shareLink.linkText").label.hasSuffix("bellohub.app/maria-silva"))

        // Go online: the fake server accepts the page and the screen says the link works.
        app.tapButton("shareLink.goOnlineButton")
        XCTAssertTrue(app.element("shareLink.online").waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["shareLink.goOnlineButton"].exists)

        // The link card and the More row follow.
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.element("bookingSettings.onlineStatus").waitForExistence(timeout: 5))
        XCTAssertTrue(app.scrollUntilExists(app.buttons["bookingSettings.stopButton"]))
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(waitForLabel(app.buttons["more.bookingPageRow"], containing: "Taking bookings"))

        // Stop: the page says it is not taking bookings and the link goes back to a preview.
        app.tapButton("more.bookingPageRow")
        XCTAssertTrue(app.scrollUntilExists(app.buttons["bookingSettings.stopButton"]))
        app.tapButton("bookingSettings.stopButton")
        app.tapButton("bookingSettings.stopConfirmButton")
        XCTAssertTrue(app.element("bookingSettings.notOnline").waitForExistence(timeout: 8))
        XCTAssertTrue(app.waitUntilGone(app.buttons["bookingSettings.stopButton"]))
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(waitForLabel(app.buttons["more.bookingPageRow"], containing: "Not online yet"))
    }

    func testWithoutAServerThePageStaysAPreview() {
        let app = XCUIApplication.launchedOnBookingSetup()
        app.openMoreRow("more.bookingPageRow")
        XCTAssertTrue(app.element("bookingSettings.notOnline").waitForExistence(timeout: 8))
        app.tapButton("bookingSettings.chooseAddressButton")
        app.tapButton("shareLink.suggestion.maria-silva")
        let save = app.buttons["shareLink.saveAddressButton"]
        XCTAssertTrue(waitUntilEnabled(save))
        save.tap()
        XCTAssertTrue(app.element("shareLink.notOnline").waitForExistence(timeout: 5))
        // No server: going online fails honestly, and the link stays a preview.
        app.tapButton("shareLink.goOnlineButton")
        XCTAssertTrue(app.element("shareLink.publishError").waitForExistence(timeout: 10))
        XCTAssertTrue(app.element("shareLink.notOnline").exists)
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
