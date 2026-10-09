//
//  AppleSignInUITests.swift
//  BelloHubUITests
//

import XCTest

/// Sign in with Apple, the main way in (D44). The system sheet cannot be driven, so the button signs the fixed dev
/// Apple user in through `LocalDevAuthProvider` when the app runs with `-uiTesting`.
@MainActor
final class AppleSignInUITests: XCTestCase {
    override func setUp() async throws {
        continueAfterFailure = false
    }

    func testAppleSignInPrefillsTheNameAndReachesHome() {
        let app = XCUIApplication.launchedForUITests()

        app.createAccountWithApple()
        XCTAssertTrue(app.staticTexts["onboarding.about.title"].waitForExistence(timeout: 5))
        let name = app.textFields["onboarding.about.nameField"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        XCTAssertEqual(name.value as? String, "Helena Duarte")
        XCTAssertNotEqual(name.placeholderValue, name.value as? String)

        app.tapButton("onboarding.about.continueButton")
        app.tapButton("onboarding.profession.choice.esthetician")
        app.tapButton("onboarding.profession.continueButton")
        for step in ["services", "terminology", "tags", "record"] {
            app.tapButton("onboarding.\(step).continueButton")
        }
        for _ in 0..<4 { app.tapButton("onboarding.permissions.allowButton") }
        app.tapButton("onboarding.permissions.continueButton")
        app.tapButton("onboarding.ready.continueButton")

        XCTAssertTrue(app.staticTexts["home.greeting"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["home.greeting"].label.contains("Helena"))
    }

    func testThePhoneStepOffersAppleToo() {
        let app = XCUIApplication.launchedForUITests()
        app.tapButton("welcome.phoneButton")
        XCTAssertTrue(app.textFields["signIn.phoneField"].waitForExistence(timeout: 5))

        app.tapButton("signIn.appleButton")

        XCTAssertTrue(app.staticTexts["onboarding.about.title"].waitForExistence(timeout: 5))
    }

    func testThePhoneWayStillWorks() {
        let app = XCUIApplication.launchedForUITests()

        app.createAccount()

        XCTAssertTrue(app.staticTexts["onboarding.about.title"].waitForExistence(timeout: 5))
        let name = app.textFields["onboarding.about.nameField"]
        // An empty field reports its placeholder as its value, so "nothing prefilled" means value == placeholder.
        XCTAssertEqual(name.value as? String, name.placeholderValue, "a phone sign-in has no name to prefill")
    }
}
