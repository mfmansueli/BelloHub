//
//  XCUIApplication+TreatmentFlow.swift
//  BelloHubUITests
//

import XCTest

extension XCUIApplication {
    /// Launches on the treatment flow (5.1 to 5.9) for the seeded client Ana Costa, who has signed a photo consent.
    /// `voice` makes dictation and structuring scripted (`-uiVoice scripted`); without it voice is not available, as in
    /// v1. The camera is always the scripted one, because a simulator has none.
    @MainActor
    static func launchedOnTreatmentFlow(
        voice: Bool = false, locale: String? = nil, largestText: Bool = false
    ) -> XCUIApplication {
        var arguments = [
            "-uiSeed", "clientWithHealth", "-uiRoute", "treatmentFlow", "-uiTreatmentFlow", "-uiCamera", "scripted"
        ]
        if voice { arguments += ["-uiVoice", "scripted"] }
        return launchedForUITests(locale: locale, largestText: largestText, arguments: arguments)
    }

    /// Types into the notes field of the form.
    @MainActor
    func typeNotes(_ text: String, file: StaticString = #filePath, line: UInt = #line) {
        let field = descendants(matching: .any).matching(identifier: "treatmentFlow.form.field.notes").firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 10), "no notes field", file: file, line: line)
        scrollAboveBottomBar(field)
        field.tap()
        field.typeText(text)
        dismissKeyboard()
    }
}
