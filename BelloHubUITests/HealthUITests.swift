//
//  HealthUITests.swift
//  BelloHubUITests
//

import XCTest

/// The health flow of one client (screen 4.5): the professional fills the health form with her, the answers appear,
/// a consent is noted as a status record (D55: a label, signed or not, the date; no text and no signature), the
/// record reopens for editing and can be marked not signed, and a patch test is recorded. The Clients tab that pushes
/// this screen belongs to another stage, so the test opens it directly (`-uiRoute health`) for the seeded client.
@MainActor
final class HealthUITests: XCTestCase {
    override func setUp() async throws {
        continueAfterFailure = false
    }

    func testFillTheHealthFormAndRecordAPatchTest() {
        let app = XCUIApplication.launchedOnHealth()

        // No form yet: the screen explains and offers the professional-filled path.
        XCTAssertTrue(app.buttons["health.fillButton"].waitForExistence(timeout: 20))
        XCTAssertFalse(app.element(withPrefix: "health.answer.").exists)
        app.tapButton("health.fillButton")

        // The sheet opens with the questions only, and Save stays off until everything is answered.
        XCTAssertTrue(app.buttons["healthForm.saveButton"].waitForExistence(timeout: 15))
        XCTAssertFalse(app.buttons["healthForm.saveButton"].isEnabled)
        XCTAssertEqual(app.switches.matching(identifier: "healthForm.agreeToggle").count, 0, "no agreement (D55)")
        XCTAssertEqual(app.textFields.matching(identifier: "healthForm.signatureField").count, 0, "no signature")
        app.answerHealthForm()
        XCTAssertTrue(
            app.buttons["healthForm.saveButton"].isEnabled,
            "\(app.healthFormState()) \(app.saveScreenshot(named: "health-form"))"
        )
        app.tapButton("healthForm.saveButton")

        // The sheet closes and the answers show on the screen, with the review; no consent was made.
        let allergies = app.element("health.answer.allergies")
        XCTAssertTrue(allergies.waitForExistence(timeout: 20))
        XCTAssertTrue(allergies.label.contains("Fragrance"), allergies.label)
        XCTAssertTrue(allergies.label.contains("Retinol"), allergies.label)
        XCTAssertTrue(app.element("health.answer.medication").label.contains("No"))
        XCTAssertTrue(app.element("health.review").label.contains("12"), "the default review period is 12 months")
        XCTAssertTrue(app.staticTexts["health.consent.empty"].exists, "filling the form notes no consent (D55)")

        // A patch test goes into the log.
        XCTAssertTrue(app.buttons["health.recordPatchTestButton"].waitForExistence(timeout: 15))
        app.tapButton("health.recordPatchTestButton")
        XCTAssertTrue(app.buttons["patch.saveButton"].waitForExistence(timeout: 15))
        XCTAssertFalse(app.buttons["patch.saveButton"].isEnabled, "a patch test needs a product")
        app.typeIntoField("Calming serum", identifier: "patch.productField")
        app.typeIntoField("Inner arm", identifier: "patch.areaField")
        app.selectChip("patch.hours.48")
        app.selectChip("patch.result.mildReaction")
        XCTAssertTrue(app.buttons["patch.saveButton"].isEnabled)
        app.tapButton("patch.saveButton")

        let patch = app.element(withPrefix: "health.patchTest.")
        XCTAssertTrue(patch.waitForExistence(timeout: 20))
        XCTAssertTrue(patch.label.contains("Calming serum"), patch.label)
        XCTAssertTrue(patch.label.contains("Inner arm"), patch.label)
        XCTAssertTrue(patch.label.contains("Mild reaction"), patch.label)
        XCTAssertFalse(app.staticTexts["health.patch.empty"].exists)
    }

    func testNoteAConsentThenEditItToNotSigned() {
        let app = XCUIApplication.launchedOnHealth()
        XCTAssertTrue(app.buttons["health.addConsentButton"].waitForExistence(timeout: 20))
        XCTAssertTrue(app.staticTexts["health.consent.empty"].exists, "no consent recorded yet")

        // A consent is noted: a label of her own, signed, dated today.
        app.tapButton("health.addConsentButton")
        XCTAssertTrue(app.buttons["consent.saveButton"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.buttons["consent.saveButton"].isEnabled, "the kind alone names a record")
        XCTAssertEqual(app.textViews.matching(identifier: "consent.text").count, 0, "no consent text (D55)")
        app.selectChip("consent.kind.photos")
        app.typeIntoField("Photos, paper form", identifier: "consent.labelField")
        app.dismissKeyboard()
        XCTAssertEqual(app.switches["consent.signedToggle"].value as? String, "1", "starts signed")
        XCTAssertTrue(app.element("consent.datePicker").exists)
        app.tapButton("consent.saveButton")

        let row = app.button(withPrefix: "health.consent.")
        XCTAssertTrue(row.waitForExistence(timeout: 20))
        XCTAssertTrue(row.label.contains("Photos, paper form"), row.label)
        XCTAssertTrue(row.label.contains("Signed"), row.label)
        XCTAssertFalse(app.staticTexts["health.consent.empty"].exists)

        // The record reopens for editing and can be marked not signed; the date goes away with it.
        row.tap()
        XCTAssertTrue(app.buttons["consent.saveButton"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.buttons["consent.deleteButton"].exists, "an existing record can be deleted")
        app.setSwitch("consent.signedToggle", on: false)
        XCTAssertFalse(app.element("consent.datePicker").exists)
        app.tapButton("consent.saveButton")
        let edited = app.button(withPrefix: "health.consent.")
        XCTAssertTrue(edited.waitForExistence(timeout: 20))
        XCTAssertTrue(edited.label.contains("Not signed"), edited.label)
        let rows = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'health.consent.'"))
        XCTAssertEqual(rows.count, 1, "editing updates the same record")
    }
}
