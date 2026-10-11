//
//  SuggestTimeUITests.swift
//  BelloHubUITests
//

import XCTest

/// "Suggest another time" on a booking request (2.10) against the in-memory inbox server (`-uiInbox fixtures`): the
/// sheet keeps a time for the client and the request is no longer waiting for an answer.
@MainActor
final class SuggestTimeUITests: XCTestCase {
    override func setUp() async throws {
        continueAfterFailure = false
    }

    func testSuggestingAnotherTimeKeepsItAndClosesTheRequest() {
        let app = XCUIApplication.launchedForUITests(arguments: ["-uiSeed", "onboarded", "-uiInbox", "fixtures"])
        app.openAlertsTab()
        let open = app.buttons["alerts.request.req-ana.action"]
        XCTAssertTrue(open.waitForExistence(timeout: 10), "the inbox did not sync")
        open.tap()

        let suggest = app.buttons["bookingRequest.suggestButton"]
        XCTAssertTrue(suggest.waitForExistence(timeout: 5), "no Suggest another time")
        app.bringIntoView(suggest)
        suggest.tap()
        XCTAssertTrue(app.element("bookingRequest.suggest.picker").waitForExistence(timeout: 5), "no picker")
        app.tapButton("bookingRequest.suggest.sendButton")

        XCTAssertTrue(app.element("bookingRequest.suggest.held").waitForExistence(timeout: 10), "the time was not kept")
        app.tapButton("bookingRequest.suggest.closeButton")
        XCTAssertFalse(app.buttons["bookingRequest.acceptButton"].waitForExistence(timeout: 3), "still waiting")
    }
}
