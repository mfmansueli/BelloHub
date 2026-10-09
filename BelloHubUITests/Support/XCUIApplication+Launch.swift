//
//  XCUIApplication+Launch.swift
//  BelloHubUITests
//

import XCTest

extension XCUIApplication {
    /// The only way UI tests start the app: `-uiTesting` makes the app run without animations.
    /// Add launch arguments for a controlled initial state here, never in individual tests.
    ///
    /// - Parameters:
    ///   - locale: one of the fourteen localization ids (`"ar"`, `"pt-BR"`). Sets the system language and
    ///     region, so right-to-left, plural rules and formatting are the real ones.
    ///   - largestText: launches at the largest Dynamic Type size (AX5).
    ///   - arguments: extra launch arguments for one test.
    @MainActor
    static func launchedForUITests(
        locale: String? = nil,
        largestText: Bool = false,
        arguments: [String] = []
    ) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTesting"]
        if let locale {
            app.launchArguments += ["-AppleLanguages", "(\(locale))", "-AppleLocale", appleLocale(for: locale),
                                    "-uiLocale", locale]
        }
        if largestText {
            app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        }
        app.launchArguments += arguments
        app.launch()
        dismissSystemDialogs()
        return app
    }

    /// The simulator sometimes raises its own "Enable Dictation?" sheet over the app after a keyboard was used in
    /// an earlier test; it belongs to Springboard and would hide every screen of the next launch. Seen on iOS 26.5.
    @MainActor
    private static func dismissSystemDialogs() {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let notNow = springboard.buttons["Not Now"]
        if notNow.waitForExistence(timeout: 1) { notNow.tap() }
    }

    /// `AppleLocale` for a localization id: the id itself with an underscore, or a typical region for a bare language.
    private static func appleLocale(for id: String) -> String {
        let regions = ["en": "en_US", "es": "es_ES", "it": "it_IT", "fr": "fr_FR", "de": "de_DE", "tr": "tr_TR",
                       "id": "id_ID", "hi": "hi_IN", "ar": "ar_SA"]
        return regions[id] ?? id.replacingOccurrences(of: "-", with: "_")
    }
}
