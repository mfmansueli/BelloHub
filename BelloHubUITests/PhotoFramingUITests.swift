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
        walkFramingReference(XCUIApplication.launchedOnTreatmentFlow())
    }

    /// At AX3 the bar grows and the preview gives way; the switch and the slider must still be on screen and work.
    func testTheFramingReferenceIsReachableAtLargeText() {
        let app = XCUIApplication.launchedForUITests(arguments: [
            "-uiSeed", "clientWithHealth", "-uiRoute", "treatmentFlow", "-uiTreatmentFlow", "-uiCamera", "scripted",
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXL"
        ])
        walkFramingReference(app)
    }

    // MARK: - Helpers

    private func walkFramingReference(_ app: XCUIApplication) {
        XCTAssertTrue(app.element("treatmentFlow.form").waitForExistence(timeout: 30))

        // First photo, before anything is written: nothing to line up with yet.
        app.tapButton("treatmentFlow.photos.takeButton")
        app.tapButton("visitForm.photos.take.before")
        XCTAssertTrue(app.buttons["treatmentFlow.camera.captureButton"].waitForExistence(timeout: 15))
        XCTAssertFalse(app.switches["treatmentFlow.camera.referenceToggle"].exists, "no earlier photo, no reference")
        app.tapButton("treatmentFlow.camera.captureButton")
        app.tapButton("treatmentFlow.camera.saveButton")
        XCTAssertTrue(app.element(withPrefix: "treatmentFlow.photos.row.").waitForExistence(timeout: 20))

        // Second photo: the first one is the reference, adjustable and switchable.
        app.tapButton("treatmentFlow.photos.takeButton")
        app.tapButton("visitForm.photos.take.after")
        XCTAssertTrue(app.buttons["treatmentFlow.camera.captureButton"].waitForExistence(timeout: 15))
        let toggle = app.switches["treatmentFlow.camera.referenceToggle"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 10), "the visit's first photo is offered")
        // Pinned above the capture button: reachable at once, without scrolling, on every screen size.
        XCTAssertTrue(toggle.isHittable, "the switch is on screen without scrolling")
        XCTAssertEqual(toggle.value as? String, "1", "shown by default")
        let slider = app.sliders["treatmentFlow.camera.referenceOpacity"]
        XCTAssertTrue(slider.exists && slider.isHittable)
        slider.adjust(toNormalizedSliderPosition: 0.9)

        app.flipSwitch("treatmentFlow.camera.referenceToggle")
        let off = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == '0'"), object: toggle)
        XCTAssertEqual(XCTWaiter().wait(for: [off], timeout: 5), .completed, "the reference can be turned off")
        XCTAssertTrue(app.waitUntilGone(slider), "the slider goes away with the reference")

        app.tapButton("treatmentFlow.camera.captureButton")
        XCTAssertTrue(app.element("treatmentFlow.camera.reviewScreen").waitForExistence(timeout: 10),
                      "taking the photo works as before")
    }
}
