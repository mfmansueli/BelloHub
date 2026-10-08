//
//  LaunchOptions.swift
//  BelloHub
//

import Foundation

/// Launch arguments, parsed once. They are test and design hooks, so they exist only in DEBUG builds:
/// in Release `current` is always the default, and the code that reads them cannot be reached.
/// More arguments (`-uiSeed`, `-uiOffline`, `-uiLocked`, `-uiTimeTravel`, ...) arrive with the features
/// that use them (docs/04-ARCHITECTURE.md section 7).
struct LaunchOptions: Equatable {
    /// Turns every animation off so UI tests never race them.
    var isUITesting = false
    /// Shows the Design Catalog instead of the app.
    var showsDesignCatalog = false
    /// Overrides the app locale (one of the fourteen localization ids), without relaunching the system.
    var uiLocaleID: String?
    /// Scrolls the Design Catalog to a section (`colors`, `typography`, `buttons`, `components`, `motion`), so a
    /// screenshot can capture it.
    var catalogSection: String?
    /// Starts the Design Catalog in dark appearance.
    var catalogDark = false
    /// Text size of the Design Catalog: `small`, `standard`, `large`, `accessibility3`, `accessibility5`.
    var catalogTextSize: String?

    init() {}

    init(arguments: [String]) {
        isUITesting = arguments.contains("-uiTesting")
        showsDesignCatalog = arguments.contains("-designCatalog")
        uiLocaleID = Self.value(after: "-uiLocale", in: arguments).flatMap { AppLocalization(rawValue: $0)?.rawValue }
        catalogSection = Self.value(after: "-catalogSection", in: arguments)
        catalogTextSize = Self.value(after: "-catalogTextSize", in: arguments)
        catalogDark = arguments.contains("-catalogDark")
    }

    private static func value(after flag: String, in arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: flag), arguments.indices.contains(index + 1) else { return nil }
        return arguments[index + 1]
    }

    static let current: LaunchOptions = {
        #if DEBUG
        LaunchOptions(arguments: ProcessInfo.processInfo.arguments)
        #else
        LaunchOptions()
        #endif
    }()
}
