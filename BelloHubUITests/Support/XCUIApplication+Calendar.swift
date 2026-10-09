//
//  XCUIApplication+Calendar.swift
//  BelloHubUITests
//

import XCTest

extension XCUIApplication {
    /// The Calendar tab is the third one in the system tab bar.
    @MainActor
    func openCalendarTab() {
        let tab = tab(2)
        XCTAssertTrue(tab.waitForExistence(timeout: 5), "no Calendar tab")
        tab.tap()
        XCTAssertTrue(element("calendar.modePicker").waitForExistence(timeout: 10), "the calendar did not open")
    }

    /// A visit is identified by `calendar.visit.<id>`; a test does not know the id, so it asks for the prefix. The
    /// menu of a visit uses `calendar.visit.menu.`, which is left out.
    @MainActor
    var calendarVisits: XCUIElementQuery {
        descendants(matching: .any).matching(NSPredicate(
            format: "identifier BEGINSWITH 'calendar.visit.' AND NOT identifier BEGINSWITH 'calendar.visit.menu.'"
        ))
    }

    /// The free hours of the day view are `calendar.slot.<hour>`.
    @MainActor
    var calendarSlots: XCUIElementQuery {
        descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'calendar.slot.'"))
    }

    /// The first free hour that can be tapped now, scrolling the day when none shows.
    @MainActor
    func firstTappableSlot(file: StaticString = #filePath, line: UInt = #line) -> XCUIElement? {
        for attempt in 0..<4 {
            XCTAssertTrue(calendarSlots.firstMatch.waitForExistence(timeout: 5), "no free hour", file: file, line: line)
            if let slot = calendarSlots.allElementsBoundByIndex.first(where: { $0.exists && $0.isHittable }) {
                return slot
            }
            if attempt.isMultiple(of: 2) { swipeUp() } else { swipeDown() }
        }
        return nil
    }

    /// Opens the menu of a visit with a long press and chooses an item by its identifier, or by its English label when
    /// the system does not carry identifiers into the menu.
    @MainActor
    func chooseVisitMenuItem(
        _ identifier: String, englishLabel: String, on visit: XCUIElement, file: StaticString = #filePath,
        line: UInt = #line
    ) {
        visit.press(forDuration: 1.2)
        let byIdentifier = buttons[identifier]
        if byIdentifier.waitForExistence(timeout: 3) {
            byIdentifier.tap()
            return
        }
        let byLabel = buttons[englishLabel]
        XCTAssertTrue(byLabel.waitForExistence(timeout: 3), "no menu item \(identifier)", file: file, line: line)
        byLabel.tap()
    }

    /// The identifiers of a chip family (`reschedule.slot.`), in order, to pick one by position.
    @MainActor
    func chips(prefix: String) -> [XCUIElement] {
        descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH %@", prefix))
            .allElementsBoundByIndex
    }
}
