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
        selectChip("healthForm.question.allergies.option.fragrance")
        selectChip("healthForm.question.allergies.option.retinol")
        selectChip("healthForm.question.medication.no")
        selectChip("healthForm.question.pregnancy.no")
        selectChip("healthForm.question.skinConditions.option.sensitive")
        selectChip("healthForm.question.healthConditions.option.none")
        selectChip("healthForm.question.recentProcedures.option.none")
        selectChip("healthForm.minor.no")
        agreeAndSign(signature: signature)
    }

    /// Taps a chip until it is selected. XCUITest scrolls a chip into view before it taps it, and a tap that lands
    /// while the scroll is still decelerating only stops the scroll, so the first tap can be lost.
    @MainActor
    func selectChip(_ identifier: String, file: StaticString = #filePath, line: UInt = #line) {
        let chip = buttons[identifier].firstMatch
        XCTAssertTrue(chip.waitForExistence(timeout: 15), "no chip \(identifier)", file: file, line: line)
        dismissKeyboard()
        scrollAboveBottomBar(chip)
        for _ in 0..<3 {
            chip.tap()
            if chip.isSelected { return }
        }
        let copies = buttons.matching(identifier: identifier).count
        XCTFail(
            "the chip \(identifier) did not get selected: frame \(chip.frame), hittable \(chip.isHittable), "
                + "copies \(copies), value \(String(describing: chip.value)), \(saveScreenshot(named: "chip"))",
            file: file, line: line
        )
    }

    /// Taps a row that opens a sheet and waits for `expected`, tapping again if the first tap was lost to a scroll.
    @MainActor
    func tapRow(
        _ identifier: String, expecting expected: String, file: StaticString = #filePath, line: UInt = #line
    ) {
        let row = buttons[identifier].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 15), "no row \(identifier)", file: file, line: line)
        for _ in 0..<3 {
            scrollAboveBottomBar(row)
            row.tap()
            if element(expected).waitForExistence(timeout: 8) { return }
        }
        XCTFail("tapping \(identifier) did not show \(expected)", file: file, line: line)
    }

    /// Types into a text field, tapping it again if the first tap was lost to a scroll.
    @MainActor
    func typeIntoField(_ text: String, identifier: String, file: StaticString = #filePath, line: UInt = #line) {
        let field = textFields[identifier].firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 15), "no field \(identifier)", file: file, line: line)
        scrollAboveBottomBar(field)
        for _ in 0..<3 {
            field.tap()
            if field.value(forKey: "hasKeyboardFocus") as? Bool == true { break }
        }
        if field.value(forKey: "hasKeyboardFocus") as? Bool != true {
            let shot = saveScreenshot(named: "focus-lost")
            XCTFail("\(identifier) has no focus: \(shot) \(field.frame)", file: file, line: line)
            return
        }
        field.typeText(text)
    }

    /// Ticks the agreement and types the signature (the last two steps of the sheet).
    @MainActor
    func agreeAndSign(signature: String) {
        let agree = switches["healthForm.agreeToggle"]
        XCTAssertTrue(agree.waitForExistence(timeout: 15), "no agreement toggle")
        scrollAboveBottomBar(agree)
        // Tapping the middle of the row toggles it (the whole card is the target). A tap lost to a scroll is tried
        // again, and as a last resort the switch itself is tapped: at the right in left-to-right languages, at the
        // left in Arabic.
        for edge in [CGFloat?.none, nil, 0.92, 0.08] where (agree.value as? String) != "1" {
            if let edge {
                agree.coordinate(withNormalizedOffset: CGVector(dx: edge, dy: 0.5)).tap()
            } else {
                agree.tap()
            }
        }
        let diagnostics = "\(healthFormState()) \(saveScreenshot(named: "agree"))"
        XCTAssertEqual(agree.value as? String, "1", "the agreement was not ticked: \(diagnostics)")
        typeIntoField(signature, identifier: "healthForm.signatureField")
    }

    /// Closes the keyboard with its return key. A chip under the keyboard cannot be scrolled clear of it (the drag
    /// would land on the keys), and a tap there types instead of selecting.
    @MainActor
    func dismissKeyboard() {
        guard keyboards.firstMatch.exists else { return }
        let returnKey = keyboards.buttons.matching(NSPredicate(format: "label ==[c] 'return' OR label ==[c] 'done'"))
            .firstMatch
        if returnKey.exists { returnKey.tap() }
        _ = keyboards.firstMatch.waitForNonExistence(timeout: 5)
    }

    /// Scrolls a sheet until `element` is clear of the Save bar that floats over its lower part. XCUITest believes
    /// anything inside the scroll view is visible, so a tap there would land on the bar. The drag ends with a hold,
    /// so the scroll does not coast and swallow the tap that follows. Does nothing when the element is already clear.
    @MainActor
    func scrollAboveBottomBar(_ element: XCUIElement) {
        let screen = windows.firstMatch.frame
        guard screen.height > 0 else { return }
        let bar = ["healthForm.saveButton", "patch.saveButton", "formTemplates.saveButton"].map { buttons[$0] }
            .first { $0.exists }
        let limit = (bar?.frame.minY ?? screen.height) - screen.height * 0.06
        for _ in 0..<6 {
            let frame = element.frame
            if frame.maxY <= limit && frame.minY >= screen.height * 0.1 { return }
            let move = max(-screen.height * 0.35, min(screen.height * 0.35, frame.midY - screen.height * 0.35))
            let fraction = move / screen.height
            // The drag starts above the bar (a drag that starts on it scrolls nothing), whatever the bar's height.
            let start = coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.55))
            let end = coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.55 - fraction))
            start.press(forDuration: 0.05, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.4)
        }
    }

    /// What the health form sheet looks like right now, for a failure message: the chips that are selected, the
    /// agreement and the signature. Costs nothing when the test passes.
    @MainActor
    func healthFormState() -> String {
        let chips = buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'healthForm.question'"))
            .allElementsBoundByIndex
        let selected = chips.filter(\.isSelected).map(\.identifier)
        let agree = switches["healthForm.agreeToggle"].value as? String ?? "nil"
        let signature = textFields["healthForm.signatureField"].value as? String ?? "nil"
        let hint = staticTexts["healthForm.incomplete"].exists
        return "selected: \(selected); agree: \(agree); signature: \(signature); incompleteHint: \(hint)"
    }

    /// Saves a screenshot to the test runner's temporary folder and returns where, for a failure message.
    @MainActor
    func saveScreenshot(named name: String) -> String {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(name).png")
        try? screenshot().pngRepresentation.write(to: url)
        return url.path
    }
}
