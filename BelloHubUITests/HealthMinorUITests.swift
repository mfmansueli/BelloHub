//
//  HealthMinorUITests.swift
//  BelloHubUITests
//

import XCTest

/// A visit for someone under 18 (D17): the guardian's consent is noted as a consent record of the guardian kind, in
/// the consents folder, not among the health forms. No guardian text and no signature (D55, D60). Part of the Full
/// plan only; the logic is covered by unit tests, and the main flow is `HealthUITests`.
@MainActor
final class HealthMinorUITests: XCTestCase {
    override func setUp() async throws {
        continueAfterFailure = false
    }

    func testTheGuardianConsentIsARecordInTheConsentsFolder() {
        let app = XCUIApplication.launchedOnHealth()
        XCTAssertTrue(app.buttons["health.addConsentButton"].waitForExistence(timeout: 20))

        app.tapButton("health.addConsentButton")
        XCTAssertTrue(app.buttons["consent.saveButton"].waitForExistence(timeout: 15))
        app.selectChip("consent.kind.guardian")
        app.tapButton("consent.saveButton")

        let consent = app.button(withPrefix: "health.consent.")
        XCTAssertTrue(consent.waitForExistence(timeout: 20))
        XCTAssertTrue(consent.label.contains("Guardian consent"), consent.label)
        XCTAssertTrue(app.staticTexts["health.forms.empty"].exists, "a consent is not a health form")
        XCTAssertFalse(app.element("health.guardianName").exists, "no guardian name is stored (D55)")
    }
}
