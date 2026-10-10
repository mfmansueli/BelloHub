//
//  ClientDataDeletionUITests.swift
//  BelloHubUITests
//

import XCTest

/// A client asks to be forgotten (D30): from her edit screen, "Delete data", confirm, and she is gone from the list.
/// The server half is queued; the unit tests cover it (`ClientDataDeletionServiceTests`).
@MainActor
final class ClientDataDeletionUITests: XCTestCase {
    override func setUp() async throws {
        continueAfterFailure = false
    }

    func testDeletingAClientsDataRemovesHerFromTheList() {
        let app = XCUIApplication.launchedForUITests(arguments: ["-uiSeed", "onboarded"])
        XCTAssertTrue(app.staticTexts["home.greeting"].waitForExistence(timeout: 10))
        app.openClientsTab()
        app.tapButton("clients.addButton")
        app.type("Ana Costa", intoField: "newClient.nameField")
        app.tapButton("newClient.saveButton")
        XCTAssertTrue(app.staticTexts["clientProfile.name"].waitForExistence(timeout: 5))

        app.tapButton("clientProfile.editButton")
        let row = app.buttons["clientEdit.deleteDataRow"]
        XCTAssertTrue(row.waitForExistence(timeout: 5), "no delete-data row")
        app.bringIntoView(row)
        row.tap()
        // The system dialog exposes its button twice (sheet and popover forms): take the first.
        let confirm = app.buttons["clientEdit.deleteDataConfirmButton"].firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 5), "no confirmation")
        confirm.tap()

        XCTAssertTrue(app.element("clients.empty").waitForExistence(timeout: 10), "she is still in the list")
    }
}
