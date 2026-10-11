//
//  ClientsUITests.swift
//  BelloHubUITests
//

import XCTest

/// The Clients flow: add a client from the Clients tab, find her in the list, open her profile and rename her.
@MainActor
final class ClientsUITests: XCTestCase {
    override func setUp() async throws {
        continueAfterFailure = false
    }

    func testAddAClientFindHerOpenHerProfileAndEditHerName() {
        let app = XCUIApplication.launchedForUITests(arguments: ["-uiSeed", "onboarded"])
        XCTAssertTrue(app.staticTexts["home.greeting"].waitForExistence(timeout: 5))

        // An empty workspace invites her to add the first client.
        app.openClientsTab()
        XCTAssertTrue(app.element("clients.empty").waitForExistence(timeout: 5))

        // Add a client: only a name is required.
        app.tapButton("clients.addButton")
        app.type("Ana Costa", intoField: "newClient.nameField")
        app.type("11981234410", intoField: "newClient.phoneField")
        app.tapButton("newClient.saveButton")

        // Saving opens her profile.
        let name = app.staticTexts["clientProfile.name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        XCTAssertEqual(name.label, "Ana Costa")

        // She is in the list.
        app.goBack()
        let row = app.clientRows.firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        XCTAssertTrue(row.label.contains("Ana Costa"), "row says: \(row.label)")

        // Open her profile from the list and edit her name.
        row.tap()
        XCTAssertTrue(app.staticTexts["clientProfile.name"].waitForExistence(timeout: 5))
        app.tapButton("clientProfile.editButton")
        app.replaceText(inField: "clientEdit.nameField", with: "Ana Maria Costa")
        app.tapButton("clientEdit.saveButton")

        // The profile shows the new name at once, and so does the list.
        let renamed = app.staticTexts["clientProfile.name"]
        XCTAssertTrue(renamed.waitForExistence(timeout: 5))
        XCTAssertEqual(renamed.label, "Ana Maria Costa")
        app.goBack()
        XCTAssertTrue(app.clientRows.firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.clientRows.firstMatch.label.contains("Ana Maria Costa"))
    }
}
