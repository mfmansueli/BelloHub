//
//  HealthUITests.swift
//  BelloHubUITests
//

import XCTest

/// The health and consent flow of one client (screen 4.5): the professional fills the health form with her, the
/// client agrees and signs by typing her name, the answers and the consent appear, the signed text opens with the
/// version it was signed on, and a patch test is recorded. The Clients tab that pushes this screen belongs to another
/// stage, so the test opens it directly (`-uiRoute health`) for the seeded client.
@MainActor
final class HealthUITests: XCTestCase {
    override func setUp() async throws {
        continueAfterFailure = false
    }

    func testFillTheHealthFormSignItReadTheSignedTextAndRecordAPatchTest() {
        let app = XCUIApplication.launchedOnHealth()

        // No form yet: the screen explains and offers the professional-filled path.
        XCTAssertTrue(app.buttons["health.fillButton"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.element(withPrefix: "health.answer.").exists)
        app.tapButton("health.fillButton")

        // The sheet opens with the questions, and Save stays off until everything is answered and signed.
        XCTAssertTrue(app.buttons["healthForm.saveButton"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["healthForm.saveButton"].isEnabled)
        app.answerHealthFormAndSign()
        XCTAssertTrue(app.buttons["healthForm.saveButton"].isEnabled)
        app.tapButton("healthForm.saveButton")

        // The sheet closes and the answers show on the screen, with the review and the consent.
        let allergies = app.element("health.answer.allergies")
        XCTAssertTrue(allergies.waitForExistence(timeout: 10))
        XCTAssertTrue(allergies.label.contains("Fragrance"), allergies.label)
        XCTAssertTrue(allergies.label.contains("Retinol"), allergies.label)
        XCTAssertTrue(app.element("health.answer.medication").label.contains("No"))
        XCTAssertTrue(app.element("health.review").label.contains("12"), "the default review period is 12 months")

        let consent = app.button(withPrefix: "health.consent.")
        XCTAssertTrue(consent.waitForExistence(timeout: 5))
        XCTAssertTrue(consent.label.contains("Ana Costa"), consent.label)
        XCTAssertTrue(consent.label.contains("2026-10"), consent.label)

        // Tapping the consent opens the exact text that was signed, with its version.
        consent.tap()
        let version = app.staticTexts["signedConsent.version"]
        XCTAssertTrue(version.waitForExistence(timeout: 5))
        XCTAssertTrue(version.label.contains("2026-10"), version.label)
        XCTAssertTrue(app.element("signedConsent.text").exists)
        XCTAssertFalse(app.element("signedConsent.missing").exists)
        app.tapButton("signedConsent.closeButton")

        // A patch test goes into the log.
        XCTAssertTrue(app.buttons["health.recordPatchTestButton"].waitForExistence(timeout: 5))
        app.tapButton("health.recordPatchTestButton")
        XCTAssertTrue(app.buttons["patch.saveButton"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["patch.saveButton"].isEnabled, "a patch test needs a product")
        app.type("Calming serum", intoField: "patch.productField")
        app.type("Inner arm", intoField: "patch.areaField")
        app.tapButton("patch.hours.48")
        app.tapButton("patch.result.mildReaction")
        XCTAssertTrue(app.buttons["patch.saveButton"].isEnabled)
        app.tapButton("patch.saveButton")

        let row = app.element(withPrefix: "health.patchTest.")
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        XCTAssertTrue(row.label.contains("Calming serum"), row.label)
        XCTAssertTrue(row.label.contains("Inner arm"), row.label)
        XCTAssertTrue(row.label.contains("Mild reaction"), row.label)
        XCTAssertFalse(app.staticTexts["health.patch.empty"].exists)
    }
}
