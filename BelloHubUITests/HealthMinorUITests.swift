//
//  HealthMinorUITests.swift
//  BelloHubUITests
//

import XCTest

/// A visit for someone under 18 (D17): the form switches to the guardian consent, asks for the young person's name,
/// and the saved screen says the form is for a minor and shows the guardian's name. Part of the Full plan only; the
/// logic is covered by unit tests, and the main flow is `HealthUITests`.
@MainActor
final class HealthMinorUITests: XCTestCase {
    override func setUp() async throws {
        continueAfterFailure = false
    }

    func testAMinorsVisitSwitchesToTheGuardianConsent() {
        let app = XCUIApplication.launchedOnHealth()
        XCTAssertTrue(app.buttons["health.fillButton"].waitForExistence(timeout: 20))
        app.tapButton("health.fillButton")
        XCTAssertTrue(app.buttons["healthForm.saveButton"].waitForExistence(timeout: 15))

        app.selectChip("healthForm.minor.yes")
        XCTAssertTrue(app.textFields["healthForm.minorNameField"].waitForExistence(timeout: 15))
        app.typeIntoField("Ana Costa", identifier: "healthForm.minorNameField")
        app.selectChip("healthForm.question.allergies.option.none")
        app.selectChip("healthForm.question.medication.no")
        app.selectChip("healthForm.question.pregnancy.no")
        app.selectChip("healthForm.question.skinConditions.option.none")
        app.selectChip("healthForm.question.healthConditions.option.none")
        app.selectChip("healthForm.question.recentProcedures.option.none")
        app.agreeAndSign(signature: "Rita Costa")
        app.tapButton("healthForm.saveButton")

        XCTAssertTrue(app.element("health.minorNotice").waitForExistence(timeout: 20))
        XCTAssertTrue(app.element("health.guardianName").label.contains("Rita Costa"))
        let consent = app.button(withPrefix: "health.consent.")
        XCTAssertTrue(consent.waitForExistence(timeout: 15))
        XCTAssertTrue(consent.label.contains("Guardian consent"), consent.label)
    }
}
