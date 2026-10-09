//
//  RecordUITests.swift
//  BelloHubUITests
//

import XCTest

/// The record screens for the seeded client Ana Costa (`-uiRecords`): her history with a locked record that is only
/// changed through a logged correction with a reason (4.7), an incident reported from her profile (4.9), a client copy
/// exported without the private notes (4.10), and the AI settings where cloud help stays off (7.5).
@MainActor
final class RecordUITests: XCTestCase {
    override func setUp() async throws {
        continueAfterFailure = false
    }

    func testHistoryCorrectsALockedRecordOnlyWithAReason() {
        let app = XCUIApplication.launchedOnRecordHistory()
        let locked = XCUIApplication.lockedRecordID

        XCTAssertTrue(app.element("recordHistory.overview").waitForExistence(timeout: 30))
        XCTAssertTrue(app.element("recordHistory.lockNotice").exists)
        XCTAssertTrue(app.element("recordHistory.record.\(locked)").exists)
        XCTAssertTrue(app.element("recordHistory.incidents").exists)
        // The correction sheet: the original stays; a new text without a reason is refused.
        app.tapRow("recordHistory.change.\(locked)", expecting: "recordHistory.correction.form")
        XCTAssertTrue(app.element("recordHistory.correction.reasonField").exists)
        app.typeIntoNote(" Cheeks calmer the next day.", identifier: "recordHistory.correction.newValueField")
        app.tapButton("recordHistory.correction.saveButton")
        XCTAssertTrue(app.element("recordHistory.correction.problem").waitForExistence(timeout: 5))

        app.typeIntoNote("Forgot the follow-up call", identifier: "recordHistory.correction.reasonField")
        app.tapButton("recordHistory.correction.saveButton")
        XCTAssertTrue(app.element("recordHistory.correction.form").waitForNonExistence(timeout: 10))

        // The trail now has two corrections (the seeded one and hers).
        let corrections = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH 'recordHistory.trail.correction.'"))
        XCTAssertTrue(corrections.element(boundBy: 1).waitForExistence(timeout: 10))
    }

    func testIncidentFromTheProfileIsSaved() {
        let app = XCUIApplication.launchedOnSeededProfile()

        app.tapRow("clientProfile.incidentRow", expecting: "incident.form")
        XCTAssertTrue(app.element("incident.clientName").label.contains("Ana"))
        app.selectChip("incident.symptom.swelling")
        app.selectChip("incident.severity.moderate")
        app.tapButton("incident.saveButton")

        XCTAssertTrue(app.element("incident.saved").waitForExistence(timeout: 10))
        app.tapButton("incident.doneButton")
        XCTAssertTrue(app.element("incident.saved").waitForNonExistence(timeout: 5))
    }

    func testExportBuildsAClientCopyWithoutPrivateNotes() {
        let app = XCUIApplication.launchedOnSeededProfile()

        app.tapRow("clientProfile.exportRow", expecting: "exportRecord.form")
        // The client's copy is the default: the private-notes switch is off and disabled. The copy for a health
        // professional frees it; back on the client's copy it goes off again.
        let notes = app.switches["exportRecord.notesToggle"]
        XCTAssertTrue(notes.waitForExistence(timeout: 5))
        XCTAssertFalse(notes.isEnabled)
        XCTAssertEqual(notes.value as? String, "0")
        let audience = app.segmentedControls["exportRecord.audience"]
        XCTAssertTrue(audience.waitForExistence(timeout: 5))
        audience.buttons.element(boundBy: 1).tap()
        XCTAssertTrue(notes.isEnabled)
        audience.buttons.element(boundBy: 0).tap()
        XCTAssertFalse(notes.isEnabled)
        XCTAssertEqual(notes.value as? String, "0")

        app.tapButton("exportRecord.exportButton")
        XCTAssertTrue(app.element("exportRecord.ready").waitForExistence(timeout: 20))
        XCTAssertTrue(app.element("exportRecord.fileName").label.hasSuffix(".pdf"))
        app.tapButton("exportRecord.backButton")
        XCTAssertTrue(app.element("exportRecord.ready").waitForNonExistence(timeout: 5))
    }

    func testAISettingsKeepCloudHelpOffAndReviewLocked() {
        let app = XCUIApplication.launchedOnAISettings()

        XCTAssertTrue(app.element("aiSettings.screen").waitForExistence(timeout: 30))
        XCTAssertTrue(app.element("aiSettings.device").exists)
        // The cloud card and the review card are one element each (the toggle inside is disabled), so what a tap
        // leaves behind is the proof: cloud help stays off, the review before saving stays on.
        let cloud = app.switches["aiSettings.cloud"]
        XCTAssertTrue(cloud.waitForExistence(timeout: 5))
        XCTAssertEqual(cloud.value as? String, "0")
        cloud.tap()
        XCTAssertEqual(cloud.value as? String, "0")
        let review = app.switches["aiSettings.reviewToggle"]
        XCTAssertTrue(review.exists)
        XCTAssertEqual(review.value as? String, "1")
        review.tap()
        XCTAssertEqual(review.value as? String, "1")

        let voice = app.switches["aiSettings.voiceToggle"]
        XCTAssertTrue(app.scrollUntilVisible(voice))
        let before = voice.value as? String
        app.flip(voice)
        XCTAssertNotEqual(voice.value as? String, before)
    }
}
