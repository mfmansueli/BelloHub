//
//  BookingStatusUITests.swift
//  BelloHubUITests
//

import XCTest

/// A link booking's state is the same in the app as on the server after the app comes back to the foreground
/// (fix-booking-status, the owner's two reports of 2026-10-12). The in-memory server (`-uiInbox`) serves Bianca's
/// confirmed booking half an hour from now; leaving the app and coming back runs the foreground sync, as on her iPhone
/// after WhatsApp.
@MainActor
final class BookingStatusUITests: XCTestCase {
    override func setUp() async throws {
        continueAfterFailure = false
    }

    /// The client moved her booking to another day on her manage page and then cancelled it while the app was away.
    func testAVisitTheClientMovedAndCancelledOnTheWebLeavesHome() throws {
        let app = try launchedWithBiancaNext(scenario: "clientOnTheWeb")

        leaveAndComeBack(app)

        let gone = NSPredicate { _, _ in
            let next = app.staticTexts["home.next.client"]
            return !next.exists || !next.label.contains("Bianca")
        }
        expectation(for: gone, evaluatedWith: nil)
        waitForExpectations(timeout: 20)
    }

    /// She cancelled the visit in the app; the foreground sync after WhatsApp must not bring "Confirmed" back.
    func testAVisitSheCancelledStaysCancelledAfterTheAppComesBack() throws {
        let app = try launchedWithBiancaNext(scenario: "linkVisit")
        app.tapButton("home.next.open")
        XCTAssertTrue(app.element("appointment.detail").waitForExistence(timeout: 10), "the visit did not open")

        app.scrollToAndTap("appointment.cancelButton")
        XCTAssertTrue(app.element("cancelAppointment.form").waitForExistence(timeout: 8))
        app.tapButton("cancelAppointment.confirmButton")
        XCTAssertTrue(app.element("cancelAppointment.done").waitForExistence(timeout: 10))
        app.tapButton("cancelAppointment.doneButton")
        let chip = app.staticTexts["appointment.statusChip"]
        XCTAssertTrue(chip.waitForExistence(timeout: 8))
        XCTAssertEqual(chip.label, "Cancelled")

        leaveAndComeBack(app)

        XCTAssertTrue(chip.waitForExistence(timeout: 20), "the visit screen did not come back")
        // The sync runs right after the app is active again; give it time to (wrongly) put "Confirmed" back.
        let confirmed = NSPredicate { _, _ in chip.exists && chip.label == "Confirmed" }
        let reverted = expectation(for: confirmed, evaluatedWith: nil)
        reverted.isInverted = true
        wait(for: [reverted], timeout: 5)
        XCTAssertEqual(chip.label, "Cancelled")
    }

    // MARK: - Helpers

    /// Home in English (the chip's words are compared) with Bianca's booking as the next visit. Skipped in the last
    /// half hour before midnight in the business zone, when her visit would be tomorrow's.
    private func launchedWithBiancaNext(scenario: String) throws -> XCUIApplication {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Sao_Paulo") ?? .current
        let minutes = calendar.component(.hour, from: Date()) * 60 + calendar.component(.minute, from: Date())
        if minutes >= 23 * 60 + 20 { throw XCTSkip("Bianca's visit would be tomorrow in São Paulo") }
        let app = XCUIApplication.launchedForUITests(
            locale: "en", arguments: ["-uiSeed", "onboarded", "-uiInbox", scenario]
        )
        let next = app.staticTexts["home.next.client"]
        XCTAssertTrue(next.waitForExistence(timeout: 20), "the link booking did not reach Home")
        XCTAssertTrue(next.label.contains("Bianca"), "the next visit is \(next.label)")
        return app
    }

    /// Home button, then the app again: the foreground sync runs (and the lock, if any, opens with the test's Face ID).
    private func leaveAndComeBack(_ app: XCUIApplication) {
        XCUIDevice.shared.press(.home)
        let left = expectation(for: NSPredicate { _, _ in app.state != .runningForeground }, evaluatedWith: nil)
        wait(for: [left], timeout: 10)
        app.activate()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))
    }
}
