//
//  HealthUITests.swift
//  BelloHubUITests
//

import XCTest

/// The health folder of one client (screen 4.5, D60): her own health form, signed with the client in person, is kept
/// as a record (a label, signed or not, the date; the app asks no health question), a consent is noted the same way
/// (D55), the record reopens for editing and can be marked not signed, and a patch test is recorded. The Clients tab
/// that pushes this screen belongs to another stage, so the test opens it directly (`-uiRoute health`) for the seeded
/// client.
@MainActor
final class HealthUITests: XCTestCase {
    override func setUp() async throws {
        continueAfterFailure = false
    }

    func testKeepAHealthFormAndRecordAPatchTest() {
        let app = XCUIApplication.launchedOnHealth()

        // An empty folder, and no questionnaire to fill in the app (D60).
        XCTAssertTrue(app.buttons["health.addFormButton"].waitForExistence(timeout: 20))
        XCTAssertTrue(app.staticTexts["health.forms.empty"].exists)
        XCTAssertFalse(app.buttons["health.fillButton"].exists, "the app asks no health question (D60)")
        XCTAssertFalse(app.element(withPrefix: "health.answer.").exists)
        app.tapButton("health.addFormButton")

        // The record sheet opens on the health-form kind, signed today.
        XCTAssertTrue(app.buttons["consent.saveButton"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.buttons["consent.kind.healthForm"].isSelected, app.saveScreenshot(named: "health-form"))
        XCTAssertEqual(app.switches["consent.signedToggle"].value as? String, "1", "starts signed")
        app.typeIntoField("Anamnesis, paper form", identifier: "consent.labelField")
        app.dismissKeyboard()
        app.tapButton("consent.saveButton")

        // The paper is in the folder, the review counts from it, and no consent was made.
        let form = app.button(withPrefix: "health.forms.")
        XCTAssertTrue(form.waitForExistence(timeout: 20))
        XCTAssertTrue(form.label.contains("Anamnesis, paper form"), form.label)
        XCTAssertTrue(form.label.contains("Signed"), form.label)
        XCTAssertTrue(app.element("health.review").label.contains("12"), "the default review period is 12 months")
        XCTAssertTrue(app.staticTexts["health.consent.empty"].exists, "a health form is not a consent")

        // A patch test goes into the log.
        app.scrollUntilHittable(app.buttons["health.recordPatchTestButton"])
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
