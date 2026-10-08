//
//  FormTemplatesUITests.swift
//  BelloHubUITests
//

import XCTest

/// The client forms settings (screen 6.14): switch a health question on, choose how often to ask again, save, and
/// read a consent text. More, which pushes this screen, belongs to another stage, so the test opens it directly
/// (`-uiRoute formTemplates`).
@MainActor
final class FormTemplatesUITests: XCTestCase {
    override func setUp() async throws {
        continueAfterFailure = false
    }

    func testChangeTheQuestionsAndHowOftenToAskAgainThenReadAConsentText() {
        let app = XCUIApplication.launchedOnFormTemplates()

        let save = app.buttons["formTemplates.saveButton"]
        XCTAssertTrue(save.waitForExistence(timeout: 20))
        XCTAssertFalse(save.isEnabled, "nothing has changed yet")
        XCTAssertTrue(app.element("formTemplates.version").label.contains("1"))

        // An esthetician's form starts with her default questions; sun exposure starts off.
        let sun = app.switches["formTemplates.question.sunExposure"]
        XCTAssertTrue(sun.waitForExistence(timeout: 15))
        XCTAssertEqual(sun.value as? String, "0")
        sun.tap()
        XCTAssertEqual(sun.value as? String, "1")
        app.tapButton("formTemplates.months.6")
        XCTAssertTrue(save.isEnabled)
        save.tap()

        // Saved: the questions changed, so this is the next version.
        let version = app.element("formTemplates.version")
        XCTAssertTrue(version.waitForExistence(timeout: 15))
        XCTAssertTrue(version.label.contains("2"), version.label)
        XCTAssertFalse(save.isEnabled)

        // The consent texts are read-only.
        app.tapButton("formTemplates.consent.consent-guardian")
        let text = app.element("consentPreview.text")
        XCTAssertTrue(text.waitForExistence(timeout: 15))
        XCTAssertTrue(app.element("consentPreview.version").label.contains("2026-10"))
        XCTAssertEqual(app.textFields.count + app.textViews.count, 0, "a legal text is never an editable field")
    }
}
