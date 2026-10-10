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

    /// The first free hour that can be tapped now, scrolling the day when none shows. An hour already past is
    /// preferred (booking it only warns), so the flow covers the case a professional logs a visit after the fact.
    ///
    /// Only a slot whose whole row lies between the pinned header and the floating tab bar counts: a row under the
    /// header reports `isHittable`, but the tap lands on the header's week strip and selects another day (that was the
    /// "past hour jumps to Monday" failure of 2026-10-10, docs/agent-notes/s12-release.md); a row under the tab bar
    /// lands on the bar (found after 18:30, when the day opens on the last hours).
    @MainActor
    func firstTappableSlot(file: StaticString = #filePath, line: UInt = #line) -> XCUIElement? {
        for attempt in 0..<4 {
            XCTAssertTrue(calendarSlots.firstMatch.waitForExistence(timeout: 5), "no free hour", file: file, line: line)
            let window = self.windows.firstMatch.frame
            let band = calendarHeaderBottom...(window.minY + window.height * 0.75)
            let candidates = calendarSlots.allElementsBoundByIndex.filter {
                $0.exists && $0.isHittable && band.contains($0.frame.minY) && band.contains($0.frame.maxY)
            }
            if let slot = candidates.first(where: { Self.slotHour($0).map { $0 < Self.currentHour } ?? false })
                ?? candidates.first {
                return slot
            }
            if attempt.isMultiple(of: 2) { swipeDown() } else { swipeUp() }
        }
        return nil
    }

    /// The bottom of the pinned calendar header: the week strip in the day mode, else the Day/Week control.
    @MainActor
    private var calendarHeaderBottom: CGFloat {
        let strip = descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH 'calendar.stripDay.'")).allElementsBoundByIndex
        let bottoms = strip.map(\.frame.maxY) + [element("calendar.modePicker").frame.maxY]
        return bottoms.max() ?? 0
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
