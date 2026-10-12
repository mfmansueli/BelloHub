//
//  ClientRecordUITests.swift
//  BelloHubUITests
//

import XCTest

/// The client record as the center of following a client: History opens first with the last visit on top, a
/// completed booking with no record says so, a visit opens its full details with the change history folded away, and
/// "Use as the base" never offers what belongs to the old visit. Seeded with `-uiRecords`.
final class ClientRecordUITests: XCTestCase {
    private let draftRecordID = "C0FFEE00-0000-4000-8000-00000000A003"
    private let pendingAppointmentID = "C0FFEE00-0000-4000-8000-00000000A004"

    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testHistoryOpensFirstWithPendingRecordAndDraft() {
        let app = XCUIApplication.launchedOnSeededProfile()

        XCTAssertTrue(app.element("clientRecord.history").waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["clientRecord.registerButton"].exists)
        XCTAssertTrue(app.element("clientRecord.visit.\(draftRecordID)").waitForExistence(timeout: 10))
        let pending = app.element("clientRecord.booking.\(pendingAppointmentID)")
        app.scrollAboveBottomBar(pending)
        XCTAssertTrue(pending.waitForExistence(timeout: 10), "a completed booking with no record is listed as pending")
        XCTAssertTrue(app.buttons["clientRecord.pending.fill.\(pendingAppointmentID)"].exists)
    }

    @MainActor
    func testVisitDetailsShowEveryFieldAndTheChangeHistory() {
        let app = XCUIApplication.launchedOnSeededProfile()
        let card = app.element("clientRecord.visit.\(XCUIApplication.lockedRecordID)")
        XCTAssertTrue(card.waitForExistence(timeout: 10))
        app.scrollAboveBottomBar(card)
        card.tap()

        XCTAssertTrue(app.element("visitDetail.overview").waitForExistence(timeout: 10))
        XCTAssertTrue(app.element("visitDetail.field.technique").exists)
        XCTAssertTrue(app.element("visitDetail.field.products").exists)
        // The aftercare reads with its correction applied.
        XCTAssertTrue(app.element("visitDetail.field.aftercare").label.contains("72"))
        let history = app.element("visitDetail.history")
        app.scrollAboveBottomBar(history)
        history.tap()
        let corrections = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH 'recordHistory.trail.correction.'"))
        XCTAssertTrue(corrections.firstMatch.waitForExistence(timeout: 10))
    }

    @MainActor
    func testReuseOffersOnlyDescriptiveParts() {
        let app = XCUIApplication.launchedOnSeededProfile()
        let card = app.element("clientRecord.visit.\(XCUIApplication.lockedRecordID)")
        XCTAssertTrue(card.waitForExistence(timeout: 10))
        app.scrollAboveBottomBar(card)
        card.tap()
        app.tapRow("visitDetail.reuseButton", expecting: "reuseVisit.part.technique")

        XCTAssertTrue(app.element("reuseVisit.part.products").exists)
        XCTAssertFalse(app.element("reuseVisit.part.result").exists)
        XCTAssertFalse(app.element("reuseVisit.part.photos").exists)
        app.tapButton("reuseVisit.cancel")
    }

    @MainActor
    func testLockedVisitIsCorrectedNotEdited() {
        let app = XCUIApplication.launchedOnSeededProfile()
        let card = app.element("clientRecord.visit.\(XCUIApplication.lockedRecordID)")
        XCTAssertTrue(card.waitForExistence(timeout: 10))
        app.scrollAboveBottomBar(card)
        card.tap()
        app.tapRow("visitDetail.completeButton", expecting: "recordHistory.correction.form")

        XCTAssertTrue(app.element("recordHistory.correction.reasonField").exists, "a locked record asks why")
        app.tapButton("recordHistory.correction.cancelButton")
    }
}
