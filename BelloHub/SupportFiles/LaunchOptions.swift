//
//  LaunchOptions.swift
//  BelloHub
//

import Foundation

/// Launch arguments, parsed once. They are test and design hooks, so they exist only in DEBUG builds:
/// in Release `current` is always the default, and the code that reads them cannot be reached.
/// More arguments (`-uiOffline`, `-uiTimeTravel`, ...) arrive with the features that use them
/// (docs/04-ARCHITECTURE.md section 7).
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
    /// `-uiDark` runs the whole app in dark appearance, for screenshots: the iOS 27 simulator's appearance switch
    /// (`simctl ui appearance`, `XCUIDevice.appearance`) reached neither this app nor Settings when it was tried.
    var uiDark = false
    /// A UI test launch starts from nothing (a fresh vault in memory, empty defaults) unless it asks to keep what
    /// the previous launch left, which is how a test relaunches the app.
    var keepsState = false
    /// A ready-made state to start from: `onboarded` is a signed-in professional with her workspace set up.
    var seed: String?
    /// How the Face ID prompt answers: `success` (default), `fail`, `cancelFirst` or `successOnce`.
    var biometricsMode: String?
    /// Text size of the Design Catalog: `small`, `standard`, `large`, `accessibility3`, `accessibility5`.
    var catalogTextSize: String?
    /// A fixture for the client import's contact picker (`four`): a UI test cannot drive the system's picker, so the
    /// import answers with these contacts at once.
    var uiContacts: String?
    /// A fixture spreadsheet for the client import (`clients`): it is read instead of showing the file importer.
    var uiSpreadsheet: String?
    /// How many clients to register before the app starts, to test the free-registration limit.
    var uiRegisteredClients: Int?
    /// Shows one screen directly instead of the tab bar, for UI tests of a screen another stage has not wired in yet:
    /// `health` (4.5, for the seeded client), `formTemplates` (6.14) or `treatmentFlow` (5.1 to 5.9).
    var route: String?
    /// The plan a UI test launches with (`-uiPlan none|active`); nil keeps the store the test build would use.
    var uiPlan: String?
    /// `scripted` replaces the voice capture and the structuring with scripted ones (the treatment flow's 5.2 to 5.4).
    var uiVoice: String?
    /// `scripted` replaces the camera with one that "takes" a generated picture (a simulator has no camera).
    var uiCamera: String?
    /// `fake` makes the booking server an in-memory fake, so a UI test can go online and see the real states without
    /// network. Without it a UI-test launch has no server at all (publishing says "not online").
    var uiOnline: String?
    /// `fixtures` fills the in-memory inbox server (`UITestInboxRepository`) with a booking request, a new booking, a
    /// reschedule request, a waitlist and a sealed health form addressed to the test key, so the inbox screens can be
    /// walked without a network. Implies `-uiOnline fake`.
    var uiInbox: String?

    init() {}

    init(arguments: [String]) {
        isUITesting = arguments.contains("-uiTesting")
        showsDesignCatalog = arguments.contains("-designCatalog")
        uiLocaleID = Self.value(after: "-uiLocale", in: arguments).flatMap { AppLocalization(rawValue: $0)?.rawValue }
        catalogSection = Self.value(after: "-catalogSection", in: arguments)
        catalogTextSize = Self.value(after: "-catalogTextSize", in: arguments)
        catalogDark = arguments.contains("-catalogDark")
        uiDark = arguments.contains("-uiDark")
        keepsState = arguments.contains("-uiKeepState")
        seed = Self.value(after: "-uiSeed", in: arguments)
        biometricsMode = Self.value(after: "-uiBiometrics", in: arguments)
        uiContacts = Self.value(after: "-uiContacts", in: arguments)
        uiSpreadsheet = Self.value(after: "-uiSpreadsheet", in: arguments)
        uiRegisteredClients = Self.value(after: "-uiRegisteredClients", in: arguments).flatMap(Int.init)
        route = Self.value(after: "-uiRoute", in: arguments)
        uiPlan = Self.value(after: "-uiPlan", in: arguments)
        uiVoice = Self.value(after: "-uiVoice", in: arguments)
        uiCamera = Self.value(after: "-uiCamera", in: arguments)
        uiOnline = Self.value(after: "-uiOnline", in: arguments)
        uiInbox = Self.value(after: "-uiInbox", in: arguments)
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
