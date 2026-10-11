//
//  ImportClientsUITests.swift
//  BelloHubUITests
//

import XCTest

/// The client import (4.6), opened from the shortcut on the last setup screen. The system's contact picker and file
/// importer cannot be driven by a UI test, so DEBUG launch arguments swap them for fixtures: `-uiContacts four` answers
/// with four contacts and `-uiSpreadsheet clients` with a CSV of six rows. `-uiRegisteredClients 8` registers eight
/// clients first, so only two free registrations are left.
@MainActor
final class ImportClientsUITests: XCTestCase {
    override func setUp() async throws {
        continueAfterFailure = false
    }

    /// Account, setup and the Ready screen, then the import sheet.
    private func openImport(_ app: XCUIApplication) {
        app.createAccount()
        app.completeSetup()
        XCTAssertTrue(app.staticTexts["onboarding.ready.title"].waitForExistence(timeout: 5))
        app.tapButton("onboarding.ready.importButton")
        XCTAssertTrue(app.staticTexts["importClients.sources.title"].waitForExistence(timeout: 5))
    }

    func testContactsPastTheFreeRegistrationsOfferThePlan() {
        let app = XCUIApplication.launchedForUITests(arguments: ["-uiContacts", "four", "-uiRegisteredClients", "8"])
        openImport(app)
        XCTAssertTrue(app.element("registration.limitNote").exists, "the limit is explained before importing")
        XCTAssertTrue(app.element("importClients.source.others").exists)
        XCTAssertFalse(app.buttons["importClients.source.others"].exists, "other apps are not available yet")

        app.tapButton("importClients.source.contacts")
        XCTAssertTrue(app.staticTexts["importClients.choose.title"].waitForExistence(timeout: 5))
        // Before confirming: four new, two free registrations left, two registered now, two waiting for a plan.
        XCTAssertTrue(app.element("importClients.plan.new").label.contains("4"), "four new")
        XCTAssertTrue(app.element("importClients.plan.now").label.contains("2"), "two go through now")
        XCTAssertTrue(app.element("importClients.plan.waiting").label.contains("2"), "two wait for a plan")
        XCTAssertTrue(app.element("importClients.plan.outcome").exists, "what happens to the rest is said")
        app.tapButton("importClients.importButton")

        let title = app.staticTexts["importClients.result.title"]
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        XCTAssertTrue(title.label.contains("2"), "two registered: \(title.label)")
        XCTAssertTrue(app.element("importClients.result.blocked").label.contains("2"), "two are waiting for a plan")

        app.tapButton("importClients.result.seePlansButton")
        XCTAssertTrue(app.staticTexts["paywall.title"].waitForExistence(timeout: 5))
        app.tapButton("paywall.closeButton")

        app.tapButton("importClients.result.viewClientsButton")
        XCTAssertTrue(app.staticTexts["onboarding.ready.title"].waitForExistence(timeout: 5), "the sheet closed")
    }

    func testASmallGroupCanBeTriedFirst() {
        let app = XCUIApplication.launchedForUITests(arguments: ["-uiContacts", "four"])
        openImport(app)

        app.tapButton("importClients.source.contacts")
        XCTAssertTrue(app.staticTexts["importClients.choose.title"].waitForExistence(timeout: 5))
        app.tapButton("importClients.trialMenu")
        app.tapButton("importClients.trial.3")
        XCTAssertTrue(app.element("importClients.plan.new").label.contains("3"), "only the first three are chosen")
        app.tapButton("importClients.importButton")

        let title = app.staticTexts["importClients.result.title"]
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        XCTAssertTrue(title.label.contains("3"), "three registered: \(title.label)")
        XCTAssertFalse(app.element("importClients.result.blocked").exists, "the trial fits the free registrations")
    }

    func testASpreadsheetIsMappedValidatedAndImported() {
        let app = XCUIApplication.launchedForUITests(arguments: ["-uiSpreadsheet", "clients"])
        openImport(app)

        app.tapButton("importClients.source.spreadsheet")
        XCTAssertTrue(app.staticTexts["importClients.mapping.title"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.element("importClients.mapping.namePicker").exists)
        XCTAssertTrue(app.element("importClients.mapping.phonePicker").exists)
        app.tapButton("importClients.mapping.continueButton")

        XCTAssertTrue(app.staticTexts["importClients.choose.title"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["importClients.row.row-2"].exists, "Ana Beatriz Costa")
        XCTAssertTrue(app.buttons["importClients.row.row-4"].exists, "the quoted name with a comma is one name")
        XCTAssertFalse(app.buttons["importClients.row.row-5"].exists, "a phone that is not valid is not offered")

        // The new people start selected; the repeated phone is marked and unticked, so the first tap selects all,
        // the second clears and the button says why it is off.
        XCTAssertTrue(app.element("importClients.plan.new").exists, "the summary comes before the button")
        app.tapButton("importClients.selectAllButton")
        app.tapButton("importClients.selectAllButton")
        XCTAssertFalse(app.buttons["importClients.importButton"].isEnabled)
        app.tapButton("importClients.selectAllButton")
        XCTAssertTrue(app.buttons["importClients.importButton"].isEnabled)
        app.tapButton("importClients.importButton")

        XCTAssertTrue(app.staticTexts["importClients.result.title"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.element("importClients.result.duplicates").exists, "the repeated phone is skipped")
        XCTAssertTrue(app.element("importClients.result.malformed").exists, "two rows could not be read")
        XCTAssertFalse(app.element("importClients.result.blocked").exists, "nothing needed a plan")

        app.tapButton("importClients.result.viewClientsButton")
        XCTAssertTrue(app.staticTexts["onboarding.ready.title"].waitForExistence(timeout: 5))
        app.tapButton("onboarding.ready.continueButton")
        XCTAssertTrue(app.staticTexts["home.greeting"].waitForExistence(timeout: 5), "setup ends with the clients in")
    }
}
