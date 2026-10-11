//
//  InfoPlistUsageTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

/// Every system permission the app asks for has its reason in the built Info.plist and in all fourteen localizations
/// (S12). A missing reason is not a review note: iOS ends the app the moment it asks (Apple Calendar had none until
/// S12).
@Suite("Info.plist usage descriptions")
struct InfoPlistUsageTests {
    /// One per permission API in the code: Face ID (`LocalAuthenticationBiometrics`), microphone and camera
    /// (`SystemPermissionProvider`, `AVCameraCapture`), contacts (`SystemContactsImporter`), calendar
    /// (`EventKitCalendarAccess`). Photos come from `PhotosPicker`, which needs no permission.
    static let keys = [
        "NSFaceIDUsageDescription", "NSMicrophoneUsageDescription", "NSCameraUsageDescription",
        "NSContactsUsageDescription", "NSCalendarsFullAccessUsageDescription"
    ]

    @Test("The built Info.plist has every reason the app needs", arguments: keys)
    func presentInInfoPlist(key: String) {
        let value = Bundle.main.object(forInfoDictionaryKey: key) as? String
        #expect(!(value ?? "").isEmpty, "\(key) is missing from the app's Info.plist")
    }

    @Test("Every reason is translated in all fourteen localizations", arguments: AppLocalization.allCases)
    func localized(localization: AppLocalization) throws {
        let path = try #require(
            Bundle.main.path(forResource: "InfoPlist", ofType: "strings", inDirectory: nil,
                             forLocalization: localization.rawValue),
            "no InfoPlist.strings for \(localization.rawValue)"
        )
        let table = try #require(NSDictionary(contentsOfFile: path) as? [String: String])
        for key in Self.keys {
            #expect(!(table[key] ?? "").isEmpty, "\(key) has no \(localization.rawValue) text")
        }
    }
}
