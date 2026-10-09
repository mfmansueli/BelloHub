//
//  MoreUITests.swift
//  BelloHubUITests
//

import XCTest

/// The More tab: her client tags (add, rename, delete) and her record fields (switch some off, add one of her own),
/// with the live numbers under the rows of More following her changes. Stage S4, screens 2.5, 6.12 and 6.13.
@MainActor
final class MoreUITests: XCTestCase {
    override func setUp() async throws {
        continueAfterFailure = false
    }

    func testManagingTagsAndRecordFields() {
        let app = XCUIApplication.launchedForUITests(arguments: ["-uiSeed", "onboarded"])
        XCTAssertTrue(app.staticTexts["home.greeting"].waitForExistence(timeout: 5))
        app.tab(4).tap()

        // The rows show where she stands: the setup left two tags and seven of the eight fields on.
        XCTAssertTrue(app.buttons["more.tagsRow"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["more.tagsRow"].label.contains("2 tags"), app.buttons["more.tagsRow"].label)
        XCTAssertTrue(
            app.buttons["more.recordFieldsRow"].label.contains("7 fields on"), app.buttons["more.recordFieldsRow"].label
        )

        // Tags: add one, rename it, delete it.
        app.tapButton("more.tagsRow")
        app.tapButton("tags.newButton")
        app.type("Bridal", intoField: "tagEditor.nameField")
        app.tapButton("tagEditor.saveButton")
        XCTAssertTrue(tagRow(named: "Bridal", in: app).waitForExistence(timeout: 5))

        tagRow(named: "Bridal", in: app).tap()
        replaceText(in: "tagEditor.nameField", with: "Bride", app: app)
        app.tapButton("tagEditor.saveButton")
        XCTAssertTrue(tagRow(named: "Bride", in: app).waitForExistence(timeout: 5))
        XCTAssertFalse(tagRow(named: "Bridal", in: app).exists)

        tagRow(named: "Bride", in: app).tap()
        app.tapButton("tagEditor.deleteButton")
        app.tapButton("tags.deleteConfirmButton")
        XCTAssertTrue(waitForNonExistence(tagRow(named: "Bride", in: app)))
        XCTAssertTrue(tagRow(named: "Sensitive Skin", in: app).exists, "the other tags are untouched")

        // Back on More the count is what it was before.
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.buttons["more.tagsRow"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["more.tagsRow"].label.contains("2 tags"), app.buttons["more.tagsRow"].label)

        // Record fields: switch two fields off, add one of her own.
        app.tapButton("more.recordFieldsRow")
        for key in ["skinCondition", "areas"] {
            let toggle = app.switches["recordTemplate.field.esthetician.\(key)"]
            XCTAssertTrue(toggle.waitForExistence(timeout: 5), key)
            XCTAssertEqual(toggle.value as? String, "1")
            flip(toggle)
            XCTAssertEqual(toggle.value as? String, "0", "\(key) is switched off at once")
        }
        app.tapButton("recordTemplate.addFieldButton")
        app.type("Mood", intoField: "fieldEditor.nameField")
        app.tapButton("fieldEditor.saveButton")
        XCTAssertTrue(customField(named: "Mood", in: app).waitForExistence(timeout: 5))

        // Everything was saved as she went: More now says six fields are on (five of the catalog and her own).
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.buttons["more.recordFieldsRow"].waitForExistence(timeout: 5))
        XCTAssertTrue(
            app.buttons["more.recordFieldsRow"].label.contains("6 fields on"), app.buttons["more.recordFieldsRow"].label
        )
    }

    // MARK: - Helpers

    /// The row of a tag by the name it reads. The identifier carries the tag's id, so the test finds the family of
    /// rows by prefix and the one it wants by its label.
    private func tagRow(named name: String, in app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'tags.row.' AND label CONTAINS %@", name))
            .firstMatch
    }

    private func customField(named name: String, in app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'recordTemplate.custom.edit.' AND label CONTAINS %@", name)
        ).firstMatch
    }

    /// Taps the switch of a row. A switch in a list row reports the whole row as its frame and its center is the
    /// label, so the tap goes to the trailing edge where the control is (the test runs in a left-to-right language).
    private func flip(_ toggle: XCUIElement) {
        toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
    }

    /// Clears a text field and types in its place: taps it, deletes what it holds, types the new text.
    private func replaceText(in identifier: String, with text: String, app: XCUIApplication) {
        let field = app.textFields[identifier]
        XCTAssertTrue(field.waitForExistence(timeout: 5), "no field \(identifier)")
        field.tap()
        let current = (field.value as? String) ?? ""
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count) + text)
    }

    private func waitForNonExistence(_ element: XCUIElement, timeout: TimeInterval = 5) -> Bool {
        let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: element)
        return XCTWaiter().wait(for: [gone], timeout: timeout) == .completed
    }
}
