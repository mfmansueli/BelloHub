//
//  AppointmentUITests.swift
//  BelloHubUITests
//

import XCTest

/// The visit screens: open a seeded visit, cancel it, and mark another visit as a no-show. The Calendar tab that pushes
/// the visit belongs to another slice, so the test opens it through the debug list (`-uiRoute appointments`).
@MainActor
final class AppointmentUITests: XCTestCase {
    override func setUp() async throws {
        continueAfterFailure = false
    }

    func testOpenAVisitAndCancelIt() {
        let app = XCUIApplication.launchedOnAppointments()
        app.tapButton("debugAppointments.upcoming")

        XCTAssertTrue(app.staticTexts["appointment.clientName"].waitForExistence(timeout: 20))
        XCTAssertEqual(app.staticTexts["appointment.clientName"].label, "Ana Costa")

        app.scrollToAndTap("appointment.cancelButton")
        XCTAssertTrue(app.element("cancelAppointment.form").waitForExistence(timeout: 8))
        app.tapButton("cancelAppointment.confirmButton")

        XCTAssertTrue(app.element("cancelAppointment.done").waitForExistence(timeout: 10))
        app.tapButton("cancelAppointment.doneButton")
        XCTAssertTrue(app.staticTexts["appointment.statusChip"].waitForExistence(timeout: 8))
    }

    func testMarkAMissedVisitAsANoShow() {
        let app = XCUIApplication.launchedOnAppointments()
        app.tapButton("debugAppointments.missed")

        XCTAssertTrue(app.staticTexts["appointment.clientName"].waitForExistence(timeout: 20))
        app.scrollToAndTap("appointment.noShowButton")
        XCTAssertTrue(app.element("noShowMark.form").waitForExistence(timeout: 8))
        app.tapButton("noShowMark.confirmButton")

        XCTAssertTrue(app.element("noShowMark.done").waitForExistence(timeout: 10))
        app.tapButton("noShowMark.doneButton")
        XCTAssertTrue(app.staticTexts["appointment.statusChip"].waitForExistence(timeout: 8))
    }
}
