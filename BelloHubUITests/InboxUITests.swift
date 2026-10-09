//
//  InboxUITests.swift
//  BelloHubUITests
//

import XCTest

/// Stage S8, screens 2.9 to 2.11 against the in-memory inbox server (`-uiInbox fixtures`): a booking request held by
/// the no-show limit is approved with the count reset, a reschedule request is accepted, and the time a client
/// cancelled is offered to somebody on the waitlist. One flow per test, in the UISmoke plan.
@MainActor
final class InboxUITests: XCTestCase {
    override func setUp() async throws {
        continueAfterFailure = false
    }

    func testApprovingABookingRequestWithTheCountReset() {
        let app = launchedOnAlerts()
        app.scrollToAndTap(prefix: "alerts.request.req-ana.action")
        XCTAssertTrue(app.element("bookingRequest.reason").waitForExistence(timeout: 5), "the reason is missing")
        XCTAssertTrue(app.element("bookingRequest.client").label.contains("Ana Costa"))

        app.bringIntoView(app.switches["bookingRequest.resetCountToggle"])
        app.flip(app.switches["bookingRequest.resetCountToggle"])
        app.tapButton("bookingRequest.acceptButton")
        XCTAssertTrue(app.element("bookingRequest.outcome").waitForExistence(timeout: 10), "no outcome")
        XCTAssertFalse(app.buttons["bookingRequest.acceptButton"].exists, "the answer buttons stayed")

        // Back on Alerts, the request is gone from the list.
        app.goBack()
        XCTAssertTrue(app.element("alerts.subtitle").waitForExistence(timeout: 5))
        XCTAssertTrue(
            app.waitUntilGone(app.element("alerts.request.req-ana"), timeout: 8), "the answered request is still listed"
        )
    }

    func testAcceptingARescheduleRequest() {
        let app = launchedOnAlerts()
        app.scrollToAndTap(prefix: "alerts.reschedule.rr-camila.action")
        XCTAssertTrue(app.element("rescheduleRequest.requested").waitForExistence(timeout: 5), "no asked time")
        XCTAssertTrue(app.element("rescheduleRequest.current").exists)
        XCTAssertTrue(app.element("rescheduleRequest.note").exists, "the client's note is missing")

        app.tapButton("rescheduleRequest.acceptButton")
        XCTAssertTrue(app.element("rescheduleRequest.outcome").waitForExistence(timeout: 10), "no outcome")
        XCTAssertFalse(app.buttons["rescheduleRequest.declineButton"].exists, "the answer buttons stayed")
    }

    func testOfferingTheOpenTimeToSomebodyWaiting() {
        let app = launchedOnAlerts()
        app.scrollToAndTap(prefix: "alerts.waitlist.action")
        XCTAssertTrue(app.element("waitlist.openTime").waitForExistence(timeout: 5), "no open time")
        XCTAssertTrue(app.element("waitlist.openTime").label.contains("Júlia Mendes"))
        XCTAssertTrue(app.element("waitlist.person.wl-paula").exists)

        app.tapButton("waitlist.offer.wl-paula")
        XCTAssertTrue(
            app.waitUntilGone(app.buttons["waitlist.offer.wl-paula"], timeout: 8), "Paula's offer button stayed"
        )
        XCTAssertTrue(app.buttons["waitlist.offer.wl-marina"].exists, "the others can still be offered")
    }

    // MARK: - Helpers

    private func launchedOnAlerts() -> XCUIApplication {
        let app = XCUIApplication.launchedForUITests(arguments: ["-uiSeed", "onboarded", "-uiInbox", "fixtures"])
        app.openAlertsTab()
        XCTAssertTrue(app.element("alerts.request.req-ana").waitForExistence(timeout: 10), "the inbox did not sync")
        return app
    }
}
