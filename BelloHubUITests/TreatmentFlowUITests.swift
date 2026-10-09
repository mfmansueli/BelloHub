//
//  TreatmentFlowUITests.swift
//  BelloHubUITests
//

import XCTest

/// The treatment flow (5.1 to 5.9) for the seeded client Ana Costa: the manual path from the register screen to saved,
/// the next session and the photos, and the scripted-voice path through the review (nothing is saved until she has
/// decided on every card). The flow is opened directly (`-uiRoute treatmentFlow`), because the screens that present it
/// belong to other stages.
@MainActor
final class TreatmentFlowUITests: XCTestCase {
    override func setUp() async throws {
        continueAfterFailure = false
    }

    func testManualPathSavesTheRecordThenSetsTheNextSessionAndAddsAPhoto() {
        let app = XCUIApplication.launchedOnTreatmentFlow()

        // Voice is not available in v1: the screen says so calmly and the form is the main action.
        XCTAssertTrue(app.element("treatmentFlow.register.reason").waitForExistence(timeout: 30))
        XCTAssertFalse(app.buttons["treatmentFlow.register.voiceButton"].exists)
        app.tapButton("treatmentFlow.register.manualButton")

        // The form: empty is not saved, and the 24-hour lock is explained.
        XCTAssertTrue(app.element("treatmentFlow.form.lockNotice").waitForExistence(timeout: 10))
        app.tapButton("treatmentFlow.form.saveButton")
        XCTAssertTrue(app.element("treatmentFlow.form.emptyError").waitForExistence(timeout: 5))
        app.typeNotes("Skin a little sensitive around the cheeks.")
        app.tapButton("treatmentFlow.form.saveButton")

        // Saved: the summary shows what she wrote.
        XCTAssertTrue(app.element("treatmentFlow.saved").waitForExistence(timeout: 15))
        XCTAssertTrue(app.element("treatmentFlow.saved.row.notes").label.contains("sensitive"))
        XCTAssertTrue(app.element("treatmentFlow.saved.lock").exists)

        // Next session: pick six weeks and write it into the record.
        app.tapButton("treatmentFlow.saved.nextSessionButton")
        XCTAssertTrue(app.element("treatmentFlow.next").waitForExistence(timeout: 10))
        app.tapButton("treatmentFlow.next.weeks.6")
        app.tapButton("treatmentFlow.next.saveButton")
        XCTAssertTrue(app.element("treatmentFlow.next.savedNotice").waitForExistence(timeout: 10))
        app.tapButton("treatmentFlow.next.skipButton")

        // Photos: take one with the (scripted) camera and keep it.
        XCTAssertTrue(app.element("treatmentFlow.saved").waitForExistence(timeout: 10))
        app.tapButton("treatmentFlow.saved.photosButton")
        XCTAssertTrue(app.element("treatmentFlow.photos.consent").waitForExistence(timeout: 10))
        app.tapButton("treatmentFlow.photos.takeButton")
        XCTAssertTrue(app.buttons["treatmentFlow.camera.captureButton"].waitForExistence(timeout: 15))
        app.tapButton("treatmentFlow.camera.captureButton")
        app.tapButton("treatmentFlow.camera.saveButton")
        XCTAssertTrue(app.element(withPrefix: "treatmentFlow.photos.row.").waitForExistence(timeout: 20))
    }

    func testVoicePathReviewsEveryFieldBeforeAnythingIsSaved() {
        let app = XCUIApplication.launchedOnTreatmentFlow(voice: true)

        XCTAssertTrue(app.buttons["treatmentFlow.register.voiceButton"].waitForExistence(timeout: 30))
        app.tapButton("treatmentFlow.register.voiceButton")
        XCTAssertTrue(app.element("treatmentFlow.listening").waitForExistence(timeout: 10))
        app.tapButton("treatmentFlow.listening.finishButton")

        // The review: Save stays off while a card is undecided.
        XCTAssertTrue(app.element("treatmentFlow.review").waitForExistence(timeout: 20))
        let save = app.buttons["treatmentFlow.review.saveButton"]
        XCTAssertTrue(save.waitForExistence(timeout: 10))
        XCTAssertFalse(save.isEnabled)
        app.tapButton("treatmentFlow.review.keepAllButton")
        XCTAssertTrue(save.isEnabled)
        save.tap()

        XCTAssertTrue(app.element("treatmentFlow.saved").waitForExistence(timeout: 15))
    }
}
