//
//  ServicesUITests.swift
//  BelloHubUITests
//

import XCTest

/// The business catalog: add a service with a contraindication and a patch test, add an add-on, and see both are still
/// there, with their settings, when she leaves the screen and comes back (the screen reads them from the vault again).
/// Stage S5, screens 6.1, 6.2 and 6.3. The vault of a UI-test launch is in memory, so a relaunch would start empty;
/// that the settings survive a real store is proven by the contract tests against SwiftData
/// (`RepositoryCatalogContractTests`).
@MainActor
final class ServicesUITests: XCTestCase {
    override func setUp() async throws {
        continueAfterFailure = false
    }

    func testAddingAServiceWithSettingsAndAnAddOn() {
        let app = XCUIApplication.launchedForUITests(arguments: ["-uiSeed", "onboarded"])
        app.openBusinessScreen(row: "more.servicesRow")

        // The setup left two services.
        XCTAssertTrue(app.button(prefix: "services.row.", containing: "Glow Facial").waitForExistence(timeout: 5))
        XCTAssertTrue(app.button(prefix: "services.row.", containing: "Deep Cleansing").exists)

        // A new service with a price, a contraindication and a patch test.
        app.tapButton("services.addButton")
        app.type("Brow Lamination", intoField: "serviceEditor.nameField")
        app.type("45", intoField: "serviceEditor.priceField")
        app.scrollUntilVisible(app.buttons["serviceEditor.contraindicationsButton"])
        app.tapButton("serviceEditor.contraindicationsButton")
        let latex = app.buttons["contraindications.option.allergies.latex"]
        XCTAssertTrue(latex.waitForExistence(timeout: 5))
        latex.tap()
        XCTAssertTrue(latex.isSelected, "the option she tapped is ticked")
        app.goBack()
        XCTAssertTrue(app.element("serviceEditor.contraindication.allergies.latex").waitForExistence(timeout: 5))
        let patchToggle = app.switches["serviceEditor.patchTestToggle"]
        XCTAssertTrue(app.scrollUntilVisible(patchToggle))
        XCTAssertEqual(patchToggle.value as? String, "0")
        app.flip(patchToggle)
        XCTAssertEqual(patchToggle.value as? String, "1")
        app.tapButton("serviceEditor.saveButton")

        let brow = app.button(prefix: "services.row.", containing: "Brow Lamination")
        XCTAssertTrue(brow.waitForExistence(timeout: 5))
        XCTAssertTrue(brow.label.contains("Patch test"), brow.label)
        XCTAssertTrue(brow.label.contains("1 contraindication"), brow.label)

        // An add-on, pushed from the services screen.
        app.tapButton("services.addOnsLink")
        app.tapButton("addOns.addButton")
        app.type("Hand massage", intoField: "addOnEditor.nameField")
        app.tapButton("addOnEditor.saveButton")
        XCTAssertTrue(app.button(prefix: "addOns.row.", containing: "Hand massage").waitForExistence(timeout: 5))
        XCTAssertTrue(app.element("addOns.preview").label.contains("Hand massage"))

        // Away and back: both are read again from the vault, with what she chose.
        app.goBack()
        XCTAssertTrue(app.buttons["services.addButton"].waitForExistence(timeout: 5))
        app.goBack()
        XCTAssertTrue(app.buttons["more.servicesRow"].waitForExistence(timeout: 5))
        app.tapButton("more.servicesRow")
        let again = app.button(prefix: "services.row.", containing: "Brow Lamination")
        XCTAssertTrue(again.waitForExistence(timeout: 5))
        again.tap()
        XCTAssertTrue(app.element("serviceEditor.contraindication.allergies.latex").waitForExistence(timeout: 5))
        XCTAssertEqual(app.textFields["serviceEditor.priceField"].value as? String, "45")
        let patchAgain = app.switches["serviceEditor.patchTestToggle"]
        XCTAssertTrue(app.scrollUntilVisible(patchAgain))
        XCTAssertEqual(patchAgain.value as? String, "1", "the patch-test setting was kept")
        app.tapButton("serviceEditor.cancelButton")

        app.tapButton("services.addOnsLink")
        XCTAssertTrue(app.button(prefix: "addOns.row.", containing: "Hand massage").waitForExistence(timeout: 5))
    }

    /// D56: prep, clean-up and processing time live in the service form, are kept, and the processing menus appear
    /// only while the switch is on.
    func testExtraAndProcessingTime() {
        let app = XCUIApplication.launchedForUITests(arguments: ["-uiSeed", "onboarded"])
        app.openBusinessScreen(row: "more.servicesRow")
        let glow = app.button(prefix: "services.row.", containing: "Glow Facial")
        XCTAssertTrue(glow.waitForExistence(timeout: 5))
        glow.tap()

        XCTAssertTrue(app.buttons["serviceEditor.prepMenu"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["serviceEditor.cleanupMenu"].exists)
        XCTAssertFalse(app.buttons["serviceEditor.processingMenu"].exists, "no processing menus while it is off")
        let processing = app.switches["serviceEditor.processingToggle"]
        XCTAssertTrue(app.scrollUntilVisible(processing))
        app.flip(processing)
        XCTAssertEqual(processing.value as? String, "1")
        XCTAssertTrue(app.buttons["serviceEditor.processingMenu"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["serviceEditor.processingStartMenu"].exists)
        app.tapButton("serviceEditor.saveButton")

        let again = app.button(prefix: "services.row.", containing: "Glow Facial")
        XCTAssertTrue(again.waitForExistence(timeout: 5))
        again.tap()
        let kept = app.switches["serviceEditor.processingToggle"]
        XCTAssertTrue(app.scrollUntilVisible(kept))
        XCTAssertEqual(kept.value as? String, "1", "the processing time was kept")
        XCTAssertTrue(app.buttons["serviceEditor.processingMenu"].exists)
        app.tapButton("serviceEditor.cancelButton")
    }
}
