//
//  XCUIApplication+Records.swift
//  BelloHubUITests
//

import XCTest

extension XCUIApplication {
    /// The record the seed locked two days ago (`RecordUITestSeeding.lockedRecordID`).
    static let lockedRecordID = "C0FFEE00-0000-4000-8000-00000000A001"

    /// Launches on the record history (4.7) of the seeded client Ana Costa, with `-uiRecords`: one locked record with a
    /// correction, one open record and one incident.
    @MainActor
    static func launchedOnRecordHistory(locale: String? = nil, largestText: Bool = false) -> XCUIApplication {
        launchedForUITests(
            locale: locale, largestText: largestText,
            arguments: ["-uiSeed", "clientWithHealth", "-uiRecords", "-uiRoute", "recordHistory"]
        )
    }

    /// Launches on the AI settings (7.5) of the seeded professional.
    @MainActor
    static func launchedOnAISettings(locale: String? = nil, largestText: Bool = false) -> XCUIApplication {
        launchedForUITests(
            locale: locale, largestText: largestText, arguments: ["-uiSeed", "onboarded", "-uiRoute", "aiSettings"]
        )
    }

    /// Launches on the app with Ana Costa's records seeded and opens her profile from the Clients tab, where the
    /// record rows (history, incident, export) live.
    @MainActor
    static func launchedOnSeededProfile(locale: String? = nil, largestText: Bool = false) -> XCUIApplication {
        let app = launchedForUITests(
            locale: locale, largestText: largestText, arguments: ["-uiSeed", "clientWithHealth", "-uiRecords"]
        )
        app.openClientsTab()
        let row = app.clientRows.firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 15), "no client row")
        row.tap()
        XCTAssertTrue(app.staticTexts["clientProfile.name"].waitForExistence(timeout: 10), "no profile")
        return app
    }

    /// Types into a multi-line note field (a vertical `TextField`), replacing nothing: the cursor goes to the end.
    @MainActor
    func typeIntoNote(_ text: String, identifier: String, file: StaticString = #filePath, line: UInt = #line) {
        let field = descendants(matching: .any).matching(identifier: identifier).firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 10), "no note field \(identifier)", file: file, line: line)
        scrollAboveBottomBar(field)
        field.tap()
        field.typeText(text)
        dismissKeyboard()
    }
}
