//
//  MotionUITests.swift
//  BelloHubUITests
//

import XCTest

/// The screens that gained motion on 2026-10-12 (docs/09-MOTION.md section 8) still work while it plays
/// (`-uiAnimate` keeps the animations on in a UI test) and with Reduce Motion (`-uiReduceMotion`): the day slides,
/// a request answered leaves its card, a queue row set aside leaves the list, the treatment flow shows its seal and
/// flashes on a shot and never blocks the next tap. Every assertion is on the final state, found by waiting on a
/// condition, so a slow simulator never fails a test that only has to settle. The default launch (`-uiTesting`) keeps
/// every other suite instant.
@MainActor
final class MotionUITests: XCTestCase {
    override func setUp() async throws {
        continueAfterFailure = false
    }

    // MARK: - Calendar: the day and the week slide

    func testTheCalendarChangesDayAndWeekWhileItAnimates() {
        walkCalendar(extra: ["-uiAnimate"])
    }

    func testTheCalendarChangesDayAndWeekWithReduceMotion() {
        walkCalendar(extra: ["-uiReduceMotion"])
    }

    private func walkCalendar(extra: [String]) {
        let app = XCUIApplication.launchedForUITests(arguments: ["-uiSeed", "clients", "-uiCalendar"] + extra)
        XCTAssertTrue(app.staticTexts["home.greeting"].waitForExistence(timeout: 10))
        app.openCalendarTab()
        let first = selectedDayLabel(app)
        XCTAssertNotNil(first, "no day is selected")

        // Next day: the strip's selection moves and the day's content is the new one.
        app.tapButton("calendar.nextButton")
        XCTAssertTrue(waitUntil { self.selectedDayLabel(app) != first }, "the selected day did not change")
        let second = selectedDayLabel(app)
        XCTAssertTrue(app.element("calendar.slot.9").waitForExistence(timeout: 5), "the new day shows no hours")

        // Back again, then a tap on a day of the strip.
        app.tapButton("calendar.previousButton")
        XCTAssertTrue(waitUntil { self.selectedDayLabel(app) == first }, "the previous day did not come back")
        let strip = app.elements(prefix: "calendar.stripDay.").allElementsBoundByIndex.last
        strip?.tap()
        XCTAssertTrue(waitUntil { self.selectedDayLabel(app) != first }, "a day of the strip was not selected")
        XCTAssertNotEqual(second, nil)

        // Week and back: the week grid is the final state (its day-view button), and the day returns.
        app.segmentedControls["calendar.modePicker"].buttons.element(boundBy: 1).tap()
        XCTAssertTrue(app.element("calendar.week.dayViewButton").waitForExistence(timeout: 8), "no week grid")
        app.tapButton("calendar.nextButton")
        XCTAssertTrue(app.element("calendar.week.dayViewButton").waitForExistence(timeout: 8), "the next week is empty")
        app.segmentedControls["calendar.modePicker"].buttons.element(boundBy: 0).tap()
        XCTAssertTrue(
            app.elements(prefix: "calendar.stripDay.").firstMatch.waitForExistence(timeout: 8), "no day strip"
        )
    }

    private func selectedDayLabel(_ app: XCUIApplication) -> String? {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH 'calendar.stripDay.' AND selected == true"))
            .allElementsBoundByIndex.first?.label
    }

    // MARK: - Alerts: an answered request leaves its card

    func testAnAnsweredRequestLeavesItsCardWhileItAnimates() {
        walkRequest(extra: ["-uiAnimate"])
    }

    func testAnAnsweredRequestLeavesItsCardWithReduceMotion() {
        walkRequest(extra: ["-uiReduceMotion"])
    }

    private func walkRequest(extra: [String]) {
        let app = XCUIApplication.launchedForUITests(
            arguments: ["-uiSeed", "onboarded", "-uiInbox", "fixtures"] + extra
        )
        app.openAlertsTab()
        XCTAssertTrue(app.element("alerts.request.req-ana").waitForExistence(timeout: 15), "the inbox did not sync")
        app.scrollToAndTap(prefix: "alerts.request.req-ana.action")
        XCTAssertTrue(app.element("bookingRequest.client").waitForExistence(timeout: 8))
        app.tapButton("bookingRequest.acceptButton")
        XCTAssertTrue(app.element("bookingRequest.outcome").waitForExistence(timeout: 10), "no outcome")
        // The brief seal never takes the touch: the way back is tappable at once.
        app.goBack()
        XCTAssertTrue(app.element("alerts.subtitle").waitForExistence(timeout: 8))
        XCTAssertTrue(
            app.waitUntilGone(app.element("alerts.request.req-ana"), timeout: 10), "the answered request is listed"
        )
        XCTAssertTrue(app.element("alerts.reschedule.rr-camila").exists, "the other request left too")
    }

    // MARK: - Follow-up queue: a row set aside leaves the list

    func testARowSetAsideLeavesTheQueueWhileItAnimates() {
        let app = XCUIApplication.launchedForUITests(arguments: ["-uiSeed", "onboarded", "-uiHome", "-uiAnimate"])
        XCTAssertTrue(app.staticTexts["home.greeting"].waitForExistence(timeout: 10), "Home did not open")
        XCTAssertTrue(app.element("home.next").waitForExistence(timeout: 10), "the next visit is not on Home")
        app.scrollToAndTap(prefix: "home.reachOut.open")
        XCTAssertTrue(app.element("followUps.subtitle").waitForExistence(timeout: 8), "the queue did not open")
        app.tapButton("followUps.filter.birthdays")
        let reasons = app.elements(prefix: "followUps.reason.birthday:")
        XCTAssertTrue(reasons.firstMatch.waitForExistence(timeout: 8), "no birthday in the queue")
        let before = reasons.count

        let menu = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'followUps.menu.birthday:'"))
        XCTAssertTrue(menu.firstMatch.waitForExistence(timeout: 5), "no menu on the birthday row")
        menu.firstMatch.tap()
        app.buttons["Dismiss"].tap()
        XCTAssertTrue(waitUntil { reasons.count < before }, "the dismissed row is still in the queue")
    }

    // MARK: - Treatment flow: the seal, the flash and the next tap

    func testTheTreatmentFlowSavesAndTakesAPhotoWhileItAnimates() {
        walkTreatmentFlow(extra: ["-uiAnimate"])
    }

    func testTheTreatmentFlowSavesAndTakesAPhotoWithReduceMotion() {
        walkTreatmentFlow(extra: ["-uiReduceMotion"])
    }

    private func walkTreatmentFlow(extra: [String]) {
        let app = XCUIApplication.launchedForUITests(arguments: [
            "-uiSeed", "clientWithHealth", "-uiRoute", "treatmentFlow", "-uiTreatmentFlow", "-uiCamera", "scripted"
        ] + extra)
        XCTAssertTrue(app.buttons["treatmentFlow.register.manualButton"].waitForExistence(timeout: 30))
        app.tapButton("treatmentFlow.register.manualButton")
        app.typeNotes("Calm skin, no reaction.")
        app.tapButton("treatmentFlow.form.saveButton")

        // Saved: the seal plays above the badge and the button below is tappable at once.
        XCTAssertTrue(app.element("treatmentFlow.saved").waitForExistence(timeout: 15))
        app.tapButton("treatmentFlow.saved.continueButton")

        // A photo: the capture flashes, the review opens, saving returns to the list with its row.
        XCTAssertTrue(app.element("treatmentFlow.photos.consent").waitForExistence(timeout: 10))
        app.tapButton("treatmentFlow.photos.takeButton")
        XCTAssertTrue(app.buttons["treatmentFlow.camera.captureButton"].waitForExistence(timeout: 15))
        app.tapButton("treatmentFlow.camera.captureButton")
        XCTAssertTrue(app.buttons["treatmentFlow.camera.saveButton"].waitForExistence(timeout: 10), "no review")
        app.tapButton("treatmentFlow.camera.saveButton")
        XCTAssertTrue(app.element(withPrefix: "treatmentFlow.photos.row.").waitForExistence(timeout: 20))

        // The brief seal is still on screen: the buttons under it answer at once.
        app.tapButton("treatmentFlow.photos.continueButton")
        XCTAssertTrue(app.element("treatmentFlow.aftercare").waitForExistence(timeout: 10))
    }

    // MARK: - Helpers

    private func waitUntil(timeout: TimeInterval = 8, _ condition: @escaping () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
        return condition()
    }
}
