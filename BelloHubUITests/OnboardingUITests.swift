//
//  OnboardingUITests.swift
//  BelloHubUITests
//

import XCTest

/// The first-run flow: welcome, phone and code, the setup steps, the permissions and the Ready screen, then the app.
@MainActor
final class OnboardingUITests: XCTestCase {
    override func setUp() async throws {
        continueAfterFailure = false
    }

    func testANewProfessionalCanSetUpAndReachHome() {
        let app = XCUIApplication.launchedForUITests()

        app.createAccount()
        XCTAssertTrue(app.staticTexts["onboarding.about.title"].waitForExistence(timeout: 5))
        app.completeSetup()

        XCTAssertTrue(app.staticTexts["onboarding.ready.title"].waitForExistence(timeout: 5))
        app.tapButton("onboarding.ready.continueButton")

        XCTAssertTrue(app.staticTexts["home.greeting"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["home.greeting"].label.contains("Maria"))
    }

    func testContinueIsDisabledUntilThereIsAName() {
        let app = XCUIApplication.launchedForUITests()
        app.createAccount()

        let continueButton = app.buttons["onboarding.about.continueButton"]
        XCTAssertTrue(continueButton.waitForExistence(timeout: 5))
        XCTAssertFalse(continueButton.isEnabled)

        app.type("Ma", intoField: "onboarding.about.nameField")
        XCTAssertTrue(continueButton.isEnabled)
    }

    func testAWrongCodeIsExplained() {
        let app = XCUIApplication.launchedForUITests()
        app.tapButton("welcome.phoneButton")
        app.type("+14155552671", intoField: "signIn.phoneField")
        app.tapButton("signIn.sendButton")

        app.type("000000", intoField: "signIn.codeField")

        XCTAssertTrue(app.staticTexts["signIn.error"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["onboarding.about.title"].exists)
    }

    func testBackReturnsToThePreviousStepAndKeepsTheChoice() {
        let app = XCUIApplication.launchedForUITests()
        app.createAccount()
        app.type("Maria", intoField: "onboarding.about.nameField")
        app.tapButton("onboarding.about.continueButton")
        app.tapButton("onboarding.profession.choice.hair")

        app.tapButton("onboarding.backButton")

        let name = app.textFields["onboarding.about.nameField"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        XCTAssertEqual(name.value as? String, "Maria")
    }

    func testRelaunchAfterSetupLandsOnTheLockScreenThenTheApp() {
        let first = XCUIApplication.launchedForUITests()
        first.createAccount()
        first.completeSetup()
        first.tapButton("onboarding.ready.continueButton")
        XCTAssertTrue(first.staticTexts["home.greeting"].waitForExistence(timeout: 5))
        first.terminate()

        // The first Face ID prompt is dismissed, so the Locked screen stays; the button then unlocks.
        let second = XCUIApplication.launchedForUITests(arguments: ["-uiKeepState", "-uiBiometrics", "cancelFirst"])
        XCTAssertTrue(second.staticTexts["locked.title"].waitForExistence(timeout: 5))
        XCTAssertFalse(second.staticTexts["home.greeting"].exists)

        second.tapButton("locked.unlockButton")
        XCTAssertTrue(second.staticTexts["home.greeting"].waitForExistence(timeout: 5))
    }
}
