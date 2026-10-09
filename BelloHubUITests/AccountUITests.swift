//
//  AccountUITests.swift
//  BelloHubUITests
//

import XCTest

/// Stage S10, screens 7.1 to 7.4 and 7.6 to 7.10: Language and region changes the previews, the recovery key is
/// revealed behind Face ID and confirmed, the Plan screen buys through the test store, and the paywall opens on the
/// 11th registration. One flow per test, in the UISmoke plan.
@MainActor
final class AccountUITests: XCTestCase {
    override func setUp() async throws {
        continueAfterFailure = false
    }

    func testChangingTheRegionChangesThePreviews() {
        let app = XCUIApplication.launchedForUITests(arguments: ["-uiSeed", "onboarded"])
        openMore(app)
        app.tapButton("more.accountRow")
        XCTAssertTrue(app.textFields["account.nameField"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.textFields["account.nameField"].value as? String, "Maria Silva")

        app.tapButton("account.languageRegionRow")
        let currency = app.element("languageRegion.sets.currency")
        let privacyLaw = app.element("languageRegion.sets.privacyLaw")
        XCTAssertTrue(currency.waitForExistence(timeout: 5))
        let currencyBefore = currency.label
        let privacyBefore = privacyLaw.label
        XCTAssertTrue(privacyBefore.contains("LGPD"), privacyBefore)
        XCTAssertFalse(app.buttons["languageRegion.saveButton"].isEnabled, "nothing changed yet")

        // Germany: the currency, the privacy law and the message previews follow, and the page offers German.
        app.tapButton("languageRegion.region.DE")
        XCTAssertTrue(waitUntil { currency.label != currencyBefore }, "currency row: \(currency.label)")
        XCTAssertTrue(currency.label.contains("€"), currency.label)
        XCTAssertTrue(privacyLaw.label.contains("GDPR"), privacyLaw.label)
        XCTAssertTrue(app.element("languageRegion.message.0").label.contains("Ana"))
        XCTAssertTrue(app.buttons["languageRegion.saveButton"].isEnabled)
        app.tapButton("languageRegion.saveButton")
        XCTAssertTrue(app.element("languageRegion.savedNotice").waitForExistence(timeout: 5))

        // The page languages: German is her language now and cannot be switched off; Portuguese left.
        app.bringIntoView(app.switches["languageRegion.pageLanguage.de"])
        XCTAssertEqual(app.switches["languageRegion.pageLanguage.de"].value as? String, "1")
        XCTAssertFalse(app.switches["languageRegion.pageLanguage.de"].isEnabled)
        XCTAssertEqual(app.switches["languageRegion.pageLanguage.pt-BR"].value as? String, "0")
    }

    func testRevealingAndConfirmingTheRecoveryKey() {
        let app = XCUIApplication.launchedForUITests(arguments: ["-uiSeed", "onboarded"])
        openMore(app)
        app.tapButton("more.privacyRow")
        let keyRow = app.buttons["privacy.recoveryKeyRow"]
        XCTAssertTrue(keyRow.waitForExistence(timeout: 5))
        XCTAssertTrue(keyRow.label.contains("Not saved yet"), keyRow.label)
        keyRow.tap()

        // Masked until Face ID (the test biometrics succeed), then twelve words.
        let firstWord = app.element("recoveryKey.word.1")
        XCTAssertTrue(firstWord.waitForExistence(timeout: 5))
        XCTAssertTrue(firstWord.label.contains("••••••"), firstWord.label)
        XCTAssertFalse(app.buttons["recoveryKey.confirmButton"].isEnabled)
        app.tapButton("recoveryKey.revealButton")
        XCTAssertTrue(waitUntil { !firstWord.label.contains("••••••") }, firstWord.label)
        XCTAssertTrue(app.element("recoveryKey.word.12").exists)

        // Confirm: the switch, then the button; Privacy shows the date.
        app.bringIntoView(app.switches["recoveryKey.confirmSwitch"])
        app.flip(app.switches["recoveryKey.confirmSwitch"])
        XCTAssertTrue(waitUntil { app.buttons["recoveryKey.confirmButton"].isEnabled })
        app.tapButton("recoveryKey.confirmButton")
        XCTAssertTrue(app.element("recoveryKey.doneNotice").waitForExistence(timeout: 5))
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(keyRow.waitForExistence(timeout: 5))
        XCTAssertTrue(waitUntil { keyRow.label.contains("Saved on") }, keyRow.label)
    }

    func testPlanScreenAndPaywall() {
        let app = XCUIApplication.launchedForUITests(
            arguments: ["-uiSeed", "onboarded", "-uiRegisteredClients", "10", "-uiPlan", "none"]
        )

        // The 11th registration opens the paywall: the Plan screen as a sheet, with the two offers.
        app.openClientsTab()
        app.tapButton("clients.addButton")
        app.type("Carla Dias", intoField: "newClient.nameField")
        app.tapButton("newClient.saveButton")
        XCTAssertTrue(app.staticTexts["paywall.title"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.element("paywall.reassurance").exists)
        XCTAssertTrue(app.buttons["plan.choice.yearly"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["plan.choice.monthly"].exists)
        XCTAssertTrue(app.buttons["plan.choice.yearly"].label.contains("17"), "the yearly saving is shown")
        app.tapButton("paywall.closeButton")
        XCTAssertTrue(waitUntil { !app.staticTexts["paywall.title"].exists })
        app.tapButton("newClient.cancelButton")

        // From More, the Plan screen buys through the test store and the status changes.
        openMore(app)
        let planRow = app.buttons["more.planRow"]
        XCTAssertTrue(planRow.waitForExistence(timeout: 5))
        XCTAssertTrue(planRow.label.contains("No plan yet"), planRow.label)
        planRow.tap()
        XCTAssertTrue(app.element("plan.status").waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["plan.choice.yearly"].waitForExistence(timeout: 5))
        app.bringIntoView(app.buttons["plan.buyButton"])
        app.tapButton("plan.buyButton")
        XCTAssertTrue(app.element("plan.notice").waitForExistence(timeout: 5))
        XCTAssertTrue(waitUntil { app.element("plan.status").label.contains("Bello Hub Pro") })
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(waitUntil { planRow.label.contains("Bello Hub Pro") }, planRow.label)
    }

    // MARK: - Helpers

    private func openMore(_ app: XCUIApplication) {
        XCTAssertTrue(app.staticTexts["home.greeting"].waitForExistence(timeout: 8))
        app.tab(4).tap()
        XCTAssertTrue(app.buttons["more.accountRow"].waitForExistence(timeout: 5))
    }

    private func waitUntil(timeout: TimeInterval = 5, _ condition: () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
        return condition()
    }
}
