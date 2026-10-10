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

    /// The hour of a `calendar.slot.<hour>` element.
    @MainActor
    static func slotHour(_ slot: XCUIElement) -> Int? {
        Int(slot.identifier.replacingOccurrences(of: "calendar.slot.", with: ""))
    }

    /// The hour now in the time zone `-uiCalendar` seeds (the calendar shows the day there).
    static var currentHour: Int {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Sao_Paulo") ?? .current
        return calendar.component(.hour, from: Date())
    }

    /// The first free hour that can be tapped now, scrolling the day when none shows.
    @MainActor
    func firstTappableSlot(file: StaticString = #filePath, line: UInt = #line) -> XCUIElement? {
        for attempt in 0..<4 {
            XCTAssertTrue(calendarSlots.firstMatch.waitForExistence(timeout: 5), "no free hour", file: file, line: line)
            // Only a slot in the middle of the screen: one under the floating tab bar or the navigation bar reports
            // `isHittable` but a tap on it lands on the bar (found after 18:30, when the day opens on the last hours).
            let window = self.windows.firstMatch.frame
            let band = (window.minY + window.height * 0.25)...(window.minY + window.height * 0.7)
            let candidates = calendarSlots.allElementsBoundByIndex.filter {
                $0.exists && $0.isHittable && band.contains($0.frame.midY)
            }
            // An hour still ahead today first: a tap on an hour that already passed did not open New appointment on
            // 2026-10-10 (the day jumped to Monday instead; open in docs/agent-notes/s11-localization.md).
            if let slot = candidates.first(where: { Self.slotHour($0).map { $0 > Self.currentHour } ?? false })
                ?? candidates.first {
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
