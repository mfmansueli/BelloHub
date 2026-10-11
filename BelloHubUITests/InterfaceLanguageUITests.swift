//
//  InterfaceLanguageUITests.swift
//  BelloHubUITests
//

import XCTest

/// Routine-a item 1: the app language chosen in Language and region applies at once to the screen that is open, to
/// the lock screen, and again after a relaunch, on an iPhone whose own language is English. The expected texts are
/// the catalog's values for each localization (pt-BR and pt-PT differ on purpose: "Idioma do app", "Idioma da app").
@MainActor
final class InterfaceLanguageUITests: XCTestCase {
    private struct Expected {
        let menuItem: String
        let appLanguageSection: String
        let screenTitle: String
        let locked: String
        let firstTab: String
    }

    override func setUp() async throws {
        continueAfterFailure = false
    }

    func testBrazilianPortugueseAppliesEverywhere() {
        check(Expected(
            menuItem: "Português (Brasil)", appLanguageSection: "Idioma do app", screenTitle: "Idioma e região",
            locked: "O Bello Hub está bloqueado.", firstTab: "Início"
        ))
    }

    func testEuropeanPortugueseAppliesEverywhere() {
        check(Expected(
            menuItem: "Português (Portugal)", appLanguageSection: "Idioma da app", screenTitle: "Idioma e região",
            locked: "O Bello Hub está bloqueado.", firstTab: "Início"
        ))
    }

    func testGermanAppliesEverywhere() {
        check(Expected(
            menuItem: "Deutsch", appLanguageSection: "Sprache der App", screenTitle: "Sprache und Region",
            locked: "Bello Hub ist gesperrt.", firstTab: "Start"
        ))
    }

    // MARK: - Helpers

    private func check(_ expected: Expected, file: StaticString = #filePath, line: UInt = #line) {
        // Face ID answers once (the cold launch), so "Lock now" leaves the lock screen up.
        let app = XCUIApplication.launchedForUITests(
            locale: "en", arguments: ["-uiSeed", "onboarded", "-uiBiometrics", "successOnce"]
        )
        XCTAssertTrue(app.staticTexts["home.greeting"].waitForExistence(timeout: 5), file: file, line: line)
        openLanguageRegion(app)
        XCTAssertTrue(app.staticTexts["App language"].waitForExistence(timeout: 5), file: file, line: line)

        // The screen that is open follows at once.
        app.buttons["languageRegion.appLanguageMenu"].firstMatch.tap()
        let item = app.buttons[expected.menuItem].firstMatch
        XCTAssertTrue(item.waitForExistence(timeout: 5), "no menu item \(expected.menuItem)", file: file, line: line)
        item.tap()
        XCTAssertTrue(app.staticTexts[expected.appLanguageSection].waitForExistence(timeout: 5), file: file, line: line)
        XCTAssertTrue(app.staticTexts[expected.screenTitle].exists || app.navigationBars[expected.screenTitle].exists,
                      "title not in the new language", file: file, line: line)
        XCTAssertEqual(app.tab(0).label, expected.firstTab, file: file, line: line)

        // The lock screen, drawn after the switch, speaks it too.
        for _ in 0..<2 { app.navigationBars.buttons.element(boundBy: 0).tap() }
        app.bringIntoView(app.buttons["more.lockNowButton"])
        app.tapButton("more.lockNowButton", file: file, line: line)
        let locked = app.staticTexts["locked.title"]
        XCTAssertTrue(locked.waitForExistence(timeout: 5), file: file, line: line)
        XCTAssertEqual(locked.label, expected.locked, file: file, line: line)
        app.terminate()

        // A relaunch on the same English iPhone: the lock screen, then the app, in her language. The first Face ID
        // prompt is dismissed so the lock screen can be read; the button unlocks.
        let second = XCUIApplication.launchedForUITests(
            locale: "en", arguments: ["-uiKeepState", "-uiBiometrics", "cancelFirst"]
        )
        let relaunchedLock = second.staticTexts["locked.title"]
        XCTAssertTrue(relaunchedLock.waitForExistence(timeout: 5), file: file, line: line)
        XCTAssertEqual(relaunchedLock.label, expected.locked, file: file, line: line)
        second.tapButton("locked.unlockButton", file: file, line: line)
        XCTAssertTrue(second.staticTexts["home.greeting"].waitForExistence(timeout: 5), file: file, line: line)
        XCTAssertEqual(second.tab(0).label, expected.firstTab, file: file, line: line)
        openLanguageRegion(second)
        XCTAssertTrue(second.staticTexts[expected.appLanguageSection].waitForExistence(timeout: 5),
                      file: file, line: line)
    }

    private func openLanguageRegion(_ app: XCUIApplication) {
        app.tab(4).tap()
        app.tapButton("more.accountRow")
        app.bringIntoView(app.buttons["account.languageRegionRow"])
        app.tapButton("account.languageRegionRow")
    }
}
