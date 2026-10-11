//
//  TimeZoneNoticeUITests.swift
//  BelloHubUITests
//

import XCTest

/// tz-mismatch-notice: the business is in São Paulo (the seed) and the iPhone somewhere else (`TZ`). Home says so with
/// a card, Calendar with a quiet row, and nothing changes until she taps.
@MainActor
final class TimeZoneNoticeUITests: XCTestCase {
    override func setUp() async throws {
        continueAfterFailure = false
    }

    func testHomeNamesBothZonesAndUsesTheIPhoneZone() {
        let app = XCUIApplication.launchedWithPhoneZone("Europe/Rome")
        let message = app.element("home.timeZoneNotice.message")
        XCTAssertTrue(message.waitForExistence(timeout: 10), "no time-zone notice on Home")
        XCTAssertTrue(message.label.contains("Rome"), "VoiceOver hears the iPhone's zone: \(message.label)")
        XCTAssertTrue(message.label.contains("São Paulo"), "VoiceOver hears the business zone: \(message.label)")
        XCTAssertTrue(app.element("home.timeZoneNotice.regionNote").exists, "Rome is in another region than Brazil")

        app.tapButton("home.timeZoneNotice.usePhone")

        XCTAssertTrue(message.waitForNonExistence(timeout: 10), "the notice stays after the zone changed")
        app.openCalendarTab()
        XCTAssertFalse(app.element("calendar.timeZoneNotice").exists, "Calendar still reports a difference")
    }

    func testKeepItHidesTheNoticeOnHomeAndCalendar() {
        let app = XCUIApplication.launchedWithPhoneZone("Asia/Tokyo")
        let notice = app.element("home.timeZoneNotice.message")
        XCTAssertTrue(notice.waitForExistence(timeout: 10), "no time-zone notice on Home")
        XCTAssertFalse(
            app.element("home.timeZoneNotice.regionNote").exists, "Tokyo belongs to no preset: no region note"
        )

        app.tapButton("home.timeZoneNotice.keep")

        XCTAssertTrue(notice.waitForNonExistence(timeout: 10), "Keep it did not hide the notice")
        app.openCalendarTab()
        XCTAssertFalse(app.element("calendar.timeZoneNotice").exists, "Calendar asks again after Keep it")
    }

    func testCalendarRowOffersTheChoicesAndOpensLanguageAndRegion() {
        let app = XCUIApplication.launchedWithPhoneZone("Europe/Rome", tab: "calendar", locale: "en")
        let row = app.element("calendar.timeZoneNotice")
        XCTAssertTrue(row.waitForExistence(timeout: 10), "no time-zone row on Calendar")
        XCTAssertTrue(row.label.contains("São Paulo") && row.label.contains("Rome"), row.label)

        row.tap()
        let link = app.menuItem("calendar.timeZoneNotice.languageRegion", englishLabel: "Language and region")
        XCTAssertTrue(link.waitForExistence(timeout: 5), "the choices did not open")
        XCTAssertTrue(
            app.menuItem("calendar.timeZoneNotice.usePhone", englishLabel: "Use my iPhone's time zone").exists
        )
        link.tap()

        XCTAssertTrue(
            app.buttons["languageRegion.saveButton"].waitForExistence(timeout: 10), "Language and region did not open"
        )
    }

    func testTheSameHourInAnotherZoneSaysNothing() {
        // Buenos Aires shows the same hour as São Paulo all year: a different id alone is not worth a notice.
        let app = XCUIApplication.launchedWithPhoneZone("America/Argentina/Buenos_Aires")
        XCTAssertTrue(app.element("home.date").waitForExistence(timeout: 5))
        XCTAssertFalse(app.element("home.timeZoneNotice").waitForExistence(timeout: 2), "a notice for the same hour")
    }
}
