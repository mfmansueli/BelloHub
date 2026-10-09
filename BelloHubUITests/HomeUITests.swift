//
//  HomeUITests.swift
//  BelloHubUITests
//

import XCTest

/// The Home flow: the seeded visits are on Home, one of them opens the visit detail, and "Send" on a reminder that
/// is ready opens the message sheet (nothing is sent by the app itself).
@MainActor
final class HomeUITests: XCTestCase {
    override func setUp() async throws {
        continueAfterFailure = false
    }

    func testTodaysVisitsOpenAndAReminderOpensTheMessageSheet() {
        let app = XCUIApplication.launchedOnHome()
        XCTAssertTrue(app.element("home.next").waitForExistence(timeout: 10), "the next visit is not on Home")
        XCTAssertTrue(app.elements(prefix: "home.visit.").firstMatch.waitForExistence(timeout: 5),
                      "the rest of today is empty")

        // A visit of "The rest of today" opens the visit detail.
        app.scrollToAndTap(prefix: "home.visit.")
        XCTAssertTrue(app.element("appointment.detail").waitForExistence(timeout: 5), "the visit did not open")
        app.goBack()
        XCTAssertTrue(app.staticTexts["home.greeting"].waitForExistence(timeout: 5))

        // "Send" on a reminder that is ready opens the message sheet; she presses send in WhatsApp herself.
        app.scrollToAndTap(prefix: "reminders.send.")
        XCTAssertTrue(app.element("messageClient.form").waitForExistence(timeout: 5),
                      "the message sheet did not open")
        app.tapButton("messageClient.closeButton")
        XCTAssertTrue(app.staticTexts["home.greeting"].waitForExistence(timeout: 5))
    }
}
