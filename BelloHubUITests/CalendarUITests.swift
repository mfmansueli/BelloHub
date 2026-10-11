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

    // MARK: - Business time zone (fix-reschedule-day)

    /// The phone twelve hours ahead of her business (São Paulo), as an iPhone in Japan for a Brazilian business (Italy
    /// is five hours ahead: the same defect). The calendar is the tab on screen at the first frame, as after an unlock,
    /// so it is built before her profile is read. A visit moved to a day must show under that day, and every visit
    /// under its own day.
    func testAMovedVisitShowsOnTheChosenDayWhenThePhoneIsAheadOfTheBusiness() {
        checkMovedVisitShowsOnTheChosenDay(phoneTimeZone: "Asia/Tokyo")
    }

    /// The phone seven hours behind her business.
    func testAMovedVisitShowsOnTheChosenDayWhenThePhoneIsBehindTheBusiness() {
        checkMovedVisitShowsOnTheChosenDay(phoneTimeZone: "Pacific/Honolulu")
    }

    // MARK: - Helpers

    private func checkMovedVisitShowsOnTheChosenDay(
        phoneTimeZone: String, file: StaticString = #filePath, line: UInt = #line
    ) {
        let app = XCUIApplication.launchedForUITests(
            arguments: ["-uiSeed", "clients", "-uiCalendar", "-uiCalendarVisits", "-uiTab", "calendar"],
            environment: ["TZ": phoneTimeZone]
        )
        XCTAssertTrue(app.element("calendar.modePicker").waitForExistence(timeout: 10), file: file, line: line)
        XCTAssertTrue(
            app.calendarVisits.firstMatch.waitForExistence(timeout: 10), "no seeded visit today", file: file, line: line
        )
        assertVisitsAreUnderTheSelectedDay(app, file: file, line: line)

        // Move today's first visit to the third day offered, at its first free time.
        app.chooseVisitMenuItem(
            "calendar.visit.menu.reschedule", englishLabel: "Reschedule", on: app.calendarVisits.firstMatch
        )
        XCTAssertTrue(app.element("reschedule.visit").waitForExistence(timeout: 5), file: file, line: line)
        let offeredDays = app.chips(prefix: "reschedule.day.")
        XCTAssertGreaterThan(offeredDays.count, 2, "too few days offered", file: file, line: line)
        offeredDays[2].tap()
        let times = app.chips(prefix: "reschedule.slot.")
        XCTAssertFalse(times.isEmpty, "the chosen day has no free time", file: file, line: line)
        times.first?.tap()
        app.tapButton("reschedule.confirmButton")
        let done = app.element("reschedule.done.time")
        XCTAssertTrue(done.waitForExistence(timeout: 5), "the move was not confirmed", file: file, line: line)
        let chosenDay = Self.day(of: done.label)
        app.tapButton("reschedule.done.backButton")

        // Go to the day she chose, by its label in the calendar, and find the visit there.
        XCTAssertTrue(app.element("calendar.modePicker").waitForExistence(timeout: 5), file: file, line: line)
        var steps = 0
        while selectedStripDay(app) != chosenDay, steps < 10 {
            app.tapButton("calendar.nextButton")
            steps += 1
        }
        XCTAssertEqual(
            selectedStripDay(app), chosenDay, "the calendar never reached the chosen day", file: file, line: line
        )
        let moved = app.calendarVisits.matching(NSPredicate(format: "label CONTAINS %@", chosenDay))
        XCTAssertTrue(
            moved.firstMatch.waitForExistence(timeout: 5), "the visit moved to \(chosenDay) is not under that day",
            file: file, line: line
        )
        assertVisitsAreUnderTheSelectedDay(app, file: file, line: line)
    }

    /// "Tuesday, October 13, 9:00 AM" → "Tuesday, October 13": the day is everything before the time.
    private static func day(of dateTime: String) -> String {
        guard let comma = dateTime.range(of: ", ", options: .backwards) else { return dateTime }
        return String(dateTime[..<comma.lowerBound])
    }

    /// The spoken label of the day selected in the week strip ("Tuesday, October 13").
    private func selectedStripDay(_ app: XCUIApplication) -> String? {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH 'calendar.stripDay.' AND selected == true"))
            .allElementsBoundByIndex.first?.label
    }

    /// Every visit the day shows is spoken with that day's date: a calendar that cuts its days in another zone than
    /// the one its labels are written in shows Tuesday's visits under Monday.
    private func assertVisitsAreUnderTheSelectedDay(
        _ app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line
    ) {
        guard let day = selectedStripDay(app) else {
            XCTFail("no day is selected in the week strip", file: file, line: line)
            return
        }
        for visit in app.calendarVisits.allElementsBoundByIndex {
            XCTAssertTrue(visit.label.contains(day), "\(visit.label) is shown under \(day)", file: file, line: line)
        }
    }
}
