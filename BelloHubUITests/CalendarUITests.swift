//
//  CalendarUITests.swift
//  BelloHubUITests
//

import XCTest

/// The calendar flow: tap a free hour, book an appointment for a client, move it from its menu and see it in the
/// calendar. `-uiCalendar` gives her a working week of every day from 09:00 to 18:00, so there is a free hour whatever
/// time the test runs.
@MainActor
final class CalendarUITests: XCTestCase {
    override func setUp() async throws {
        continueAfterFailure = false
    }

    func testBookFromAFreeHourThenRescheduleIt() {
        let app = XCUIApplication.launchedForUITests(arguments: ["-uiSeed", "clients", "-uiCalendar"])
        XCTAssertTrue(app.staticTexts["home.greeting"].waitForExistence(timeout: 10))
        app.openCalendarTab()
        XCTAssertFalse(app.calendarVisits.firstMatch.exists, "the calendar should start empty")

        // Tap a free hour: New appointment opens on that time.
        let slot = app.firstTappableSlot()
        XCTAssertNotNil(slot, "no free hour could be tapped")
        slot?.tap()
        XCTAssertTrue(app.element("newAppointment.confirmButton").waitForExistence(timeout: 5))

        // Choose the first client and the first service, then book. A time that already passed only warns.
        app.tapButton("newAppointment.client.0")
        app.tapButton("newAppointment.service.0")
        let confirm = app.buttons["newAppointment.confirmButton"]
        XCTAssertTrue(confirm.isEnabled, "the appointment cannot be booked")
        confirm.tap()

        // She is back on the calendar and the appointment is there.
        XCTAssertTrue(app.element("calendar.modePicker").waitForExistence(timeout: 5))
        let visit = app.calendarVisits.firstMatch
        XCTAssertTrue(visit.waitForExistence(timeout: 5), "the booked appointment is not in the calendar")
        let bookedLabel = visit.label
        XCTAssertFalse(bookedLabel.isEmpty, "the appointment has no spoken description")

        // Move it from its menu: pick the last free time offered.
        app.chooseVisitMenuItem("calendar.visit.menu.reschedule", englishLabel: "Reschedule", on: visit)
        XCTAssertTrue(app.element("reschedule.visit").waitForExistence(timeout: 5))
        let times = app.chips(prefix: "reschedule.slot.")
        XCTAssertFalse(times.isEmpty, "no free time to move the appointment to")
        times.last?.tap()
        let move = app.buttons["reschedule.confirmButton"]
        XCTAssertTrue(move.waitForExistence(timeout: 5))
        XCTAssertTrue(move.isEnabled, "the new time was not accepted")
        move.tap()
        XCTAssertTrue(app.element("reschedule.done").waitForExistence(timeout: 5), "the move was not confirmed")
        app.tapButton("reschedule.done.backButton")

        // It is still in her calendar: today if the new time is today, otherwise the next day.
        XCTAssertTrue(app.element("calendar.modePicker").waitForExistence(timeout: 5))
        if !app.calendarVisits.firstMatch.waitForExistence(timeout: 3) {
            app.tapButton("calendar.nextButton")
        }
        XCTAssertTrue(app.calendarVisits.firstMatch.waitForExistence(timeout: 5), "the moved appointment is gone")
        XCTAssertEqual(app.calendarVisits.count, 1)
    }
}
