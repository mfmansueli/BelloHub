//
//  XCUIApplication+Onboarding.swift
//  BelloHubUITests
//

import XCTest

extension XCUIApplication {
    /// The fixed code of the development sign-in provider (`LocalDevAuthProvider.fixedCode`).
    static let developmentCode = "123456"

    /// Types into a text field by its identifier: taps it first so the keyboard is up.
    @MainActor
    func type(_ text: String, intoField identifier: String, file: StaticString = #filePath, line: UInt = #line) {
        let field = textFields[identifier]
        XCTAssertTrue(field.waitForExistence(timeout: 5), "no field \(identifier)", file: file, line: line)
        field.tap()
        field.typeText(text)
    }

    /// Taps a button by its identifier once it exists.
    @MainActor
    func tapButton(_ identifier: String, file: StaticString = #filePath, line: UInt = #line) {
        let button = buttons[identifier].firstMatch
        XCTAssertTrue(button.waitForExistence(timeout: 5), "no button \(identifier)", file: file, line: line)
        button.tap()
    }

    /// Any element with this identifier, whatever its type (a combined card reads as a static text or an "other").
    @MainActor
    func element(_ identifier: String) -> XCUIElement {
        descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    /// A tab of the system tab bar. The system draws the bar and does not pass identifiers to its buttons, so the tab
    /// is found by position, which holds in every language.
    @MainActor
    func tab(_ position: Int) -> XCUIElement {
        tabBars.buttons.element(boundBy: position)
    }

    /// Welcome, then a new phone number and the development code: lands on the first setup step. The default number
    /// is in international form, so it is valid whatever region the test runs in.
    @MainActor
    func createAccount(phone: String = "+14155552671") {
        tapButton("welcome.phoneButton")
        type(phone, intoField: "signIn.phoneField")
        tapButton("signIn.sendButton")
        type(Self.developmentCode, intoField: "signIn.codeField")
    }

    /// Welcome, then Sign in with Apple through the development stub (no system sheet): lands on the first setup step
    /// with the stub's name ("Helena Duarte") already filled in.
    @MainActor
    func createAccountWithApple() {
        tapButton("signIn.appleButton")
    }

    /// Walks the whole setup with the first profession and the suggested defaults, ending on the Ready screen.
    @MainActor
    func completeSetup(name: String = "Maria Silva", profession: String = "esthetician") {
        type(name, intoField: "onboarding.about.nameField")
        tapButton("onboarding.about.continueButton")
        tapButton("onboarding.profession.choice.\(profession)")
        tapButton("onboarding.profession.continueButton")
        for step in ["services", "terminology", "tags", "record"] {
            tapButton("onboarding.\(step).continueButton")
        }
        for _ in 0..<4 { tapButton("onboarding.permissions.allowButton") }
        tapButton("onboarding.permissions.continueButton")
    }
}
