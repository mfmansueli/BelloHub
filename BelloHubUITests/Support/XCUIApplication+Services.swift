//
//  XCUIApplication+Services.swift
//  BelloHubUITests
//

import XCTest

extension XCUIApplication {
    /// Opens the More tab and, from it, one of the business screens by the identifier of its row.
    @MainActor
    func openBusinessScreen(row identifier: String, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(staticTexts["home.greeting"].waitForExistence(timeout: 10), "no home", file: file, line: line)
        tab(4).tap()
        XCTAssertTrue(buttons[identifier].waitForExistence(timeout: 5), "no row \(identifier)", file: file, line: line)
        buttons[identifier].tap()
    }

    /// The first button whose identifier starts with `prefix` and whose label contains `text`. List rows carry the id
    /// of what they show in their identifier, so a test finds the family by prefix and the one it wants by its label.
    @MainActor
    func button(prefix: String, containing text: String) -> XCUIElement {
        buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@ AND label CONTAINS %@", prefix, text)).firstMatch
    }

    /// Drags up until `element` is on screen: a sheet or a list builds only what is near the screen, and a form taller
    /// than the screen has its last controls out of view. The drag starts in the upper half of the screen, because a
    /// swipe that starts low would press a key of the keyboard when it is up.
    @MainActor
    @discardableResult
    func scrollUntilVisible(_ element: XCUIElement, limit: Int = 10) -> Bool {
        var drags = 0
        while !(element.exists && element.isHittable), drags < limit {
            drag(from: 0.5, to: 0.2)
            drags += 1
        }
        return element.exists && element.isHittable
    }

    /// Drags the content down in short steps until the element can be tapped, and no further: inside a sheet, a drag
    /// past the top of the content moves the sheet itself.
    @MainActor
    func scrollUpUntilVisible(_ element: XCUIElement, limit: Int = 12) -> Bool {
        var drags = 0
        while !(element.exists && element.isHittable), drags < limit {
            drag(from: 0.35, to: 0.55)
            drags += 1
        }
        return element.exists && element.isHittable
    }

    /// Drags down until the top of the screen is showing again.
    @MainActor
    func scrollToTop(limit: Int = 8) {
        for _ in 0..<limit { drag(from: 0.25, to: 0.7) }
    }

    /// Drags up to the bottom of a list or form.
    @MainActor
    func scrollToBottom(limit: Int = 8) {
        for _ in 0..<limit { drag(from: 0.6, to: 0.2) }
    }

    /// A short vertical drag on the middle of the screen, between two heights given as a share of the screen's.
    @MainActor
    private func drag(from startShare: CGFloat, to endShare: CGFloat) {
        let start = coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: startShare))
        let end = coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: endShare))
        start.press(forDuration: 0.05, thenDragTo: end)
    }

    /// Taps the switch of a row. A switch in a row reports the whole row as its frame and its center is the label, so
    /// the tap goes to the trailing edge where the control is (the tests that use it run in a left-to-right language).
    @MainActor
    func flip(_ toggle: XCUIElement) {
        toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
    }
}
