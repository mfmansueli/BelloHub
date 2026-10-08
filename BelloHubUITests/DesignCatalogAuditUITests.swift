//
//  DesignCatalogAuditUITests.swift
//  BelloHubUITests
//

import XCTest

/// Accessibility audit of the Design Catalog in several localizations, at the default size and at AX5
/// (the largest Dynamic Type size). Slow, so it runs in the Full plan and is skipped by UISmoke.
/// Exit criterion of stage S1: the catalog renders without clipped text at AX5 and in `ar` and `hi`.
@MainActor
final class DesignCatalogAuditUITests: XCTestCase {
    private static let sections = ["typography", "buttons", "components"]
    private static let locales = ["en", "pt-BR", "de", "ar", "hi"]

    override func setUp() async throws {
        continueAfterFailure = true
    }

    func testNoClippedTextAtDefaultSize() throws {
        try audit(largestText: false)
    }

    func testNoClippedTextAtLargestSize() throws {
        try audit(largestText: true)
    }

    /// Xcode's Double-Length pseudolanguage doubles every localized string, a stand-in for German and French
    /// expansion (+35 % and +25 %) with room to spare.
    func testNoClippedTextWithDoubleLengthStrings() throws {
        try audit(largestText: false, locales: ["en"], extraArguments: ["-NSDoubleLocalizedStrings", "YES"])
    }

    private func audit(largestText: Bool, locales: [String]? = nil, extraArguments: [String] = []) throws {
        for locale in locales ?? Self.locales {
            for section in Self.sections {
                let app = XCUIApplication.launchedForUITests(
                    locale: locale, largestText: largestText,
                    arguments: ["-designCatalog", "-catalogSection", section] + extraArguments
                )
                XCTAssertTrue(app.otherElements["catalog.root"].waitForExistence(timeout: 5),
                              "\(locale) \(section) did not render")
                try app.performAccessibilityAudit(for: [.textClipped, .sufficientElementDescription]) { issue in
                    XCTFail("[\(locale), \(section), largest=\(largestText)] \(issue.compactDescription)")
                    return true // reported above; keep auditing the rest of the screen
                }
                app.terminate()
            }
        }
    }
}
