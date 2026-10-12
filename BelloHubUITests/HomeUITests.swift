//
//  HomeUITests.swift
//  BelloHubUITests
//

import XCTest

/// The Home flow (routine-a item 4): the seeded visits are on Home, one of them opens the visit detail, today's
/// reminders open the follow-up queue and its message sheet (nothing is sent by the app itself), and "New
/// appointment" is in the navigation bar.
@MainActor
final class HomeUITests: XCTestCase {
    override func setUp() async throws {
        continueAfterFailure = false
    }

    func testTodaysVisitsOpenAndAReminderOpensTheMessageSheet() {
        let app = XCUIApplication.launchedOnHome()
        XCTAssertTrue(app.element("home.next").waitForExistence(timeout: 10), "the next visit is not on Home")
        XCTAssertTrue(app.elements(prefix: "home.visit.").firstMatch.waitForExistence(timeout: 5),
                      "the rest of today is empty")

        // A visit of "The rest of today" opens the visit detail.
        app.scrollToAndTap(prefix: "home.visit.")
        XCTAssertTrue(app.element("appointment.detail").waitForExistence(timeout: 5), "the visit did not open")
        app.goBack()
        XCTAssertTrue(app.staticTexts["home.greeting"].waitForExistence(timeout: 5))

        // "Today" lists the reminder that is ready; the queue opens on its reminders, and "Send reminder" opens the
        // message sheet. She presses send in WhatsApp herself; the row then says the chat was opened, not sent.
        app.scrollToAndTap(prefix: "home.today.reminders")
        XCTAssertTrue(app.element("followUps.subtitle").waitForExistence(timeout: 5), "the queue did not open")
        XCTAssertTrue(app.elements(prefix: "followUps.reason.reminder:").firstMatch.waitForExistence(timeout: 5))
        app.scrollToAndTap(prefix: "followUps.action.reminder:")
        XCTAssertTrue(app.element("messageClient.form").waitForExistence(timeout: 5),
                      "the message sheet did not open")
        app.tapButton("messageClient.closeButton")
        XCTAssertTrue(app.element("followUps.subtitle").waitForExistence(timeout: 5))
    }

    func testNewAppointmentIsOneTapAwayAndTheQueueGroupsAClient() {
        let app = XCUIApplication.launchedOnHome()
        XCTAssertTrue(app.buttons["home.quick.newAppointment"].isHittable, "New appointment is not one tap away")
        app.scrollToAndTap(prefix: "home.reachOut.open")
        XCTAssertTrue(app.element("followUps.subtitle").waitForExistence(timeout: 5))
        XCTAssertTrue(app.elements(prefix: "followUps.reason.").firstMatch.waitForExistence(timeout: 5),
                      "every suggestion says why it is there")
        app.tapButton("followUps.filter.birthdays")
        XCTAssertTrue(app.elements(prefix: "followUps.reason.birthday:").firstMatch.waitForExistence(timeout: 5))
        app.goBack()
        app.tapButton("home.quick.newAppointment")
        XCTAssertTrue(app.buttons["newAppointment.cancelButton"].waitForExistence(timeout: 5))
    }

    func testRecordsToFollowUpAndRegisterVisitOpenTheVisitForm() {
        let app = XCUIApplication.launchedOnHome()
        // Julia's visit earlier today is completed with nothing written: it waits under "To follow up".
        app.scrollToAndTap(prefix: "home.records.unwritten:")
        XCTAssertTrue(app.element("treatmentFlow.form").waitForExistence(timeout: 10), "the visit form did not open")
        // Nothing written: the form closes at once and leaves no draft.
        app.tapButton("treatmentFlow.register.cancelButton")

        app.scrollToTop()
        app.tapButton("home.quick.registerVisit")
        XCTAssertTrue(app.element("clientPicker.list").waitForExistence(timeout: 5), "no client picker")
        app.tapButton("clientPicker.client.\(Self.julia)")
        XCTAssertTrue(app.element("treatmentFlow.form").waitForExistence(timeout: 10), "no visit form for Julia")
    }

    // MARK: - Helpers

    /// Julia Mendes in `HomeUITestSeeding`.
    private static let julia = "A9902200-0000-4000-8000-000000000001"
}