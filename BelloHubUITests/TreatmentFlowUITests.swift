//
//  TreatmentFlowUITests.swift
//  BelloHubUITests
//

import XCTest

/// The visit flow for the seeded client Ana Costa: a photo before any field, the note and the next visit on the same
/// form, Finalize and the compact confirmation; closing keeps the draft; and the scripted-voice path through the
/// review (nothing goes into the form until she has decided on every card). The flow is opened directly
/// (`-uiRoute treatmentFlow`).
@MainActor
final class TreatmentFlowUITests: XCTestCase {
    override func setUp() async throws {
        continueAfterFailure = false
    }

    func testPhotoFirstThenFieldsThenFinalize() {
        let app = XCUIApplication.launchedOnTreatmentFlow()

        // Voice is not available in v1: the form is the first screen and no dictation is offered.
        XCTAssertTrue(app.element("treatmentFlow.form").waitForExistence(timeout: 30))
        XCTAssertFalse(app.buttons["treatmentFlow.register.voiceButton"].exists)
        // Empty is not finalized.
        app.tapButton("treatmentFlow.form.saveButton")
        XCTAssertTrue(app.element("treatmentFlow.form.emptyError").waitForExistence(timeout: 5))

        // A photo first, before any field: the (scripted) camera, then back to the form with the photo in it.
        app.tapButton("treatmentFlow.photos.takeButton")
        XCTAssertTrue(app.buttons["treatmentFlow.camera.captureButton"].waitForExistence(timeout: 15))
        app.tapButton("treatmentFlow.camera.captureButton")
        app.tapButton("treatmentFlow.camera.saveButton")
        XCTAssertTrue(app.element(withPrefix: "treatmentFlow.photos.row.").waitForExistence(timeout: 20))
        XCTAssertTrue(app.element("visitForm.autosave").label.isEmpty == false)

        // Then the note, the next visit, and Finalize.
        app.typeNotes("Skin a little sensitive around the cheeks.")
        let sixWeeks = app.buttons["treatmentFlow.next.weeks.6"]
        app.scrollAboveBottomBar(sixWeeks)
        sixWeeks.tap()
        app.tapButton("treatmentFlow.form.saveButton")

        // The compact confirmation: open the record, book the return, or finish.
        XCTAssertTrue(app.element("treatmentFlow.saved").waitForExistence(timeout: 15))
        XCTAssertTrue(app.element("treatmentFlow.saved.summary").label.contains("sensitive"))
        XCTAssertTrue(app.buttons["treatmentFlow.saved.historyButton"].exists)
        XCTAssertTrue(app.buttons["treatmentFlow.next.bookButton"].exists)
        app.tapButton("treatmentFlow.saved.doneButton")
        XCTAssertTrue(app.element("treatmentFlow.debug.closed").waitForExistence(timeout: 10))
    }

    func testClosingKeepsTheDraftForLater() {
        let app = XCUIApplication.launchedOnTreatmentFlow()
        XCTAssertTrue(app.element("treatmentFlow.form").waitForExistence(timeout: 30))
        app.typeNotes("Calm skin.")

        app.tapButton("treatmentFlow.register.cancelButton")
        app.tapButton("treatmentFlow.keepButton")
        XCTAssertTrue(app.element("treatmentFlow.debug.closed").waitForExistence(timeout: 10))
    }

    func testFinalizedRecordOpensItsDetails() {
        let app = XCUIApplication.launchedOnTreatmentFlow()
        XCTAssertTrue(app.element("treatmentFlow.form").waitForExistence(timeout: 30))
        app.typeNotes("Calm skin.")
        app.tapButton("treatmentFlow.form.saveButton")
        XCTAssertTrue(app.element("treatmentFlow.saved").waitForExistence(timeout: 15))

        app.tapButton("treatmentFlow.saved.historyButton")
        XCTAssertTrue(app.element("visitDetail.overview").waitForExistence(timeout: 10))
        XCTAssertTrue(app.element("visitDetail.field.notes").label.contains("Calm"))
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
        // "Keep all" sits under the cards; on some screen sizes it peeks out under the save bar, where a tap would
        // land on the bar, so scroll until the whole button is above it.
        let keepAll = app.buttons["treatmentFlow.review.keepAllButton"]
        XCTAssertTrue(keepAll.waitForExistence(timeout: 8))
        var swipes = 0
        while keepAll.frame.maxY > save.frame.minY, swipes < 6 {
            app.swipeUp()
            swipes += 1
        }
        keepAll.tap()
        XCTAssertTrue(save.isEnabled)
        save.tap()

        // The kept answers go back into the form; she reads them and finalizes herself.
        XCTAssertTrue(app.element("treatmentFlow.form").waitForExistence(timeout: 15))
        app.tapButton("treatmentFlow.form.saveButton")
        XCTAssertTrue(app.element("treatmentFlow.saved").waitForExistence(timeout: 15))
    }
}
