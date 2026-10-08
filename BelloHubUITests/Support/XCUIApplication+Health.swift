//
//  XCUIApplication+Health.swift
//  BelloHubUITests
//

import XCTest

extension XCUIApplication {
    /// Launches on the Health and consent screen of the seeded client Ana Costa (`-uiSeed clientWithHealth`,
    /// `-uiRoute health`), who has no health form yet.
    @MainActor
    static func launchedOnHealth(
        locale: String? = nil, largestText: Bool = false, extraArguments: [String] = []
    ) -> XCUIApplication {
        launchedForUITests(
            locale: locale, largestText: largestText,
            arguments: ["-uiSeed", "clientWithHealth", "-uiRoute", "health"] + extraArguments
        )
    }

    /// Launches on the form settings (6.14) of the seeded professional.
    @MainActor
    static func launchedOnFormTemplates(locale: String? = nil, largestText: Bool = false) -> XCUIApplication {
        launchedForUITests(
            locale: locale, largestText: largestText,
            arguments: ["-uiSeed", "onboarded", "-uiRoute", "formTemplates"]
        )
    }

    /// A button whose identifier starts with `prefix` (rows with an id in their identifier).
    @MainActor
    func button(withPrefix prefix: String) -> XCUIElement {
        buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", prefix)).firstMatch
    }

    /// Any element whose identifier starts with `prefix`.
    @MainActor
    func element(withPrefix prefix: String) -> XCUIElement {
        descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH %@", prefix)).firstMatch
    }

    /// Opens the health form sheet of an esthetician (the seeded profession) and answers every question: a real
    /// answer where it is interesting (allergies, a skin condition) and "no" or "none" elsewhere. Stops with the
    /// consent agreed and signed, ready to tap Save.
    @MainActor
    func answerHealthFormAndSign(signature: String = "Ana Costa") {
        tapButton("healthForm.question.allergies.option.fragrance")
        tapButton("healthForm.question.allergies.option.retinol")
        tapButton("healthForm.question.medication.no")
        tapButton("healthForm.question.pregnancy.no")
        tapButton("healthForm.question.skinConditions.option.sensitive")
        tapButton("healthForm.question.healthConditions.option.none")
        tapButton("healthForm.question.recentProcedures.option.none")
        tapButton("healthForm.minor.no")
        agreeAndSign(signature: signature)
    }

    /// Ticks the agreement and types the signature (the last two steps of the sheet).
    @MainActor
    func agreeAndSign(signature: String) {
        let agree = switches["healthForm.agreeToggle"]
        XCTAssertTrue(agree.waitForExistence(timeout: 5), "no agreement toggle")
        agree.tap()
        type(signature, intoField: "healthForm.signatureField")
    }
}
