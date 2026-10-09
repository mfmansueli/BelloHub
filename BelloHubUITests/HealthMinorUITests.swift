//
//  HealthMinorUITests.swift
//  BelloHubUITests
//

import XCTest

/// A visit for someone under 18 (D17): the form asks for the young person's name, and the saved screen says the form
/// is for a minor and shows that name. No guardian text and no signature (D55): the guardian's consent is noted as a
/// consent record of the guardian kind. Part of the Full plan only; the logic is covered by unit tests, and the main
/// flow is `HealthUITests`.
@MainActor
final class HealthMinorUITests: XCTestCase {
    override func setUp() async throws {
        continueAfterFailure = false
    }

    func testAMinorsVisitAsksForTheNameAndTheGuardianConsentIsARecord() {
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
        XCTAssertTrue(app.buttons["healthForm.saveButton"].isEnabled, app.healthFormState())
        app.tapButton("healthForm.saveButton")

        XCTAssertTrue(app.element("health.minorNotice").waitForExistence(timeout: 20))
        XCTAssertTrue(app.element("health.minorName").label.contains("Ana Costa"))
        XCTAssertFalse(app.element("health.guardianName").exists, "no guardian name is stored (D55)")

        app.tapButton("health.addConsentButton")
        XCTAssertTrue(app.buttons["consent.saveButton"].waitForExistence(timeout: 15))
        app.selectChip("consent.kind.guardian")
        app.tapButton("consent.saveButton")
        let consent = app.button(withPrefix: "health.consent.")
        XCTAssertTrue(consent.waitForExistence(timeout: 20))
        XCTAssertTrue(consent.label.contains("Guardian consent"), consent.label)
    }
}
