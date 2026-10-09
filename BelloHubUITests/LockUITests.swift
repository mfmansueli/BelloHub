//
//  LockUITests.swift
//  BelloHubUITests
//

import XCTest

@MainActor
final class LockUITests: XCTestCase {
    override func setUp() async throws {
        continueAfterFailure = false
    }

    func testAFaceThatDoesNotMatchStaysLockedAndSaysSo() {
        let app = XCUIApplication.launchedForUITests(arguments: ["-uiSeed", "onboarded", "-uiBiometrics", "fail"])

        XCTAssertTrue(app.staticTexts["locked.title"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.element("locked.error").waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["home.greeting"].exists)
    }

    func testLockNowFromMoreLocksTheApp() {
        // Face ID succeeds once (the cold-launch unlock) and is dismissed after that, so the lock stays visible.
        let app = XCUIApplication.launchedForUITests(
            arguments: ["-uiSeed", "onboarded", "-uiBiometrics", "successOnce"]
        )
        XCTAssertTrue(app.staticTexts["home.greeting"].waitForExistence(timeout: 5))

        app.tab(4).tap()
        app.tapButton("more.lockNowButton")

        XCTAssertTrue(app.staticTexts["locked.title"].waitForExistence(timeout: 5))
    }

    func testSigningOutReturnsToTheWelcome() {
        let app = XCUIApplication.launchedForUITests(arguments: ["-uiSeed", "onboarded"])
        XCTAssertTrue(app.staticTexts["home.greeting"].waitForExistence(timeout: 5))

        // Sign out lives in Account (7.1) since S10.
        app.tab(4).tap()
        app.tapButton("more.accountRow")
        app.bringIntoView(app.buttons["account.signOutButton"])
        app.tapButton("account.signOutButton")
        app.tapButton("account.signOutConfirmButton")

        XCTAssertTrue(app.buttons["welcome.getStartedButton"].waitForExistence(timeout: 5))
    }
}
