//
//  PhotoFramingUITests.swift
//  BelloHubUITests
//

import XCTest

/// The camera's framing reference (routine item 11) for the seeded client Ana Costa: the first photo of the visit has
/// no reference; once a "before" is saved, the next photo's camera offers "Show previous photo" with its slider, and
/// turning it off hides the slider. The camera is scripted (`-uiCamera scripted`), so this runs on the simulator.
@MainActor
final class PhotoFramingUITests: XCTestCase {
    override func setUp() async throws {
        continueAfterFailure = false
    }

    func testThePreviousPhotoIsOfferedAsAFramingReference() {
        let app = XCUIApplication.launchedOnTreatmentFlow()

        XCTAssertTrue(app.buttons["treatmentFlow.register.manualButton"].waitForExistence(timeout: 30))
        app.tapButton("treatmentFlow.register.manualButton")
        app.typeNotes("Skin a little sensitive around the cheeks.")
        app.tapButton("treatmentFlow.form.saveButton")
        XCTAssertTrue(app.element("treatmentFlow.saved").waitForExistence(timeout: 15))
        app.tapButton("treatmentFlow.saved.photosButton")

        // First photo: nothing to line up with yet.
        app.tapButton("treatmentFlow.photos.takeButton")
        XCTAssertTrue(app.buttons["treatmentFlow.camera.captureButton"].waitForExistence(timeout: 15))
        XCTAssertFalse(app.switches["treatmentFlow.camera.referenceToggle"].exists, "no earlier photo, no reference")
        app.tapButton("treatmentFlow.camera.captureButton")
        app.tapButton("treatmentFlow.camera.saveButton")
        XCTAssertTrue(app.element(withPrefix: "treatmentFlow.photos.row.").waitForExistence(timeout: 20))

        // Second photo: the first one is the reference, adjustable and switchable.
        app.tapButton("treatmentFlow.photos.takeButton")
        XCTAssertTrue(app.buttons["treatmentFlow.camera.captureButton"].waitForExistence(timeout: 15))
        let toggle = app.switches["treatmentFlow.camera.referenceToggle"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 10), "the visit's first photo is offered")
        XCTAssertTrue(app.scrollUntilVisible(toggle))
        XCTAssertEqual(toggle.value as? String, "1", "shown by default")
        let slider = app.sliders["treatmentFlow.camera.referenceOpacity"]
        XCTAssertTrue(slider.exists)
        slider.adjust(toNormalizedSliderPosition: 0.9)

        app.flip(toggle)
        XCTAssertEqual(toggle.value as? String, "0")
        XCTAssertFalse(slider.exists, "the slider goes away with the reference")

        app.tapButton("treatmentFlow.camera.captureButton")
        XCTAssertTrue(app.element("treatmentFlow.camera.reviewScreen").waitForExistence(timeout: 10),
                      "taking the photo works as before")
    }
}
