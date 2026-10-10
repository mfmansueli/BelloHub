//
//  MailboxAlertsUITests.swift
//  BelloHubUITests
//

import XCTest

/// "From your clients" in Alerts (docs/06 section 3.5) against the in-memory inbox server (`-uiInbox fixtures`): the
/// sealed health form of the fixtures is opened on the simulator and imported into Helena's record, the card says so,
/// and "Got it" clears it.
@MainActor
final class MailboxAlertsUITests: XCTestCase {
    override func setUp() async throws {
        continueAfterFailure = false
    }

    func testImportedHealthFormIsAnnouncedAndCleared() {
        let app = XCUIApplication.launchedForUITests(arguments: ["-uiSeed", "onboarded", "-uiInbox", "fixtures"])
        app.openAlertsTab()
        let card = app.element("alerts.mailbox.imported")
        XCTAssertTrue(card.waitForExistence(timeout: 30), "the sealed form was not imported")

        let done = app.buttons["alerts.mailbox.imported.action"]
        app.bringIntoView(done)
        done.tap()

        XCTAssertTrue(card.waitForNonExistence(timeout: 5), "the card stayed")
    }
}
