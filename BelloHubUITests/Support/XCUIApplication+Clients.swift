//
//  XCUIApplication+Clients.swift
//  BelloHubUITests
//

import XCTest

extension XCUIApplication {
    /// The Clients tab is the second one in the system tab bar.
    @MainActor
    func openClientsTab() {
        let tab = tab(1)
        XCTAssertTrue(tab.waitForExistence(timeout: 5), "no Clients tab")
        tab.tap()
    }

    /// Client rows are identified by `clients.row.<id>`; a test does not know the id, so it asks for the prefix.
    @MainActor
    var clientRows: XCUIElementQuery {
        descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'clients.row.'"))
    }

    /// Replaces what is in a text field: puts the cursor at its end and deletes every character before typing.
    @MainActor
    func replaceText(
        inField identifier: String, with text: String, file: StaticString = #filePath, line: UInt = #line
    ) {
        let field = textFields[identifier]
        XCTAssertTrue(field.waitForExistence(timeout: 5), "no field \(identifier)", file: file, line: line)
        field.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
        let current = (field.value as? String) ?? ""
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count))
        field.typeText(text)
    }

    /// The back button of the navigation bar (the first button on its leading edge).
    @MainActor
    func goBack() {
        let back = navigationBars.buttons.element(boundBy: 0)
        XCTAssertTrue(back.waitForExistence(timeout: 5), "no back button")
        back.tap()
    }
}
