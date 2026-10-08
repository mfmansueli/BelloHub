//
//  GoogleServiceInfoTests.swift
//  BelloHubTests
//

import Foundation
import Testing

@Suite("GoogleService-Info.plist")
struct GoogleServiceInfoTests {
    /// Firebase rejects an app whose bundle ID differs from the one registered in the console.
    /// Changing the bundle ID without downloading a new plist fails here instead of at runtime.
    @Test("The bundled plist is registered for this app's bundle ID")
    func plistMatchesBundleIdentifier() throws {
        let url = try #require(Bundle.main.url(forResource: "GoogleService-Info", withExtension: "plist"))
        let data = try Data(contentsOf: url)
        let info = try #require(PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any])

        #expect(info["BUNDLE_ID"] as? String == Bundle.main.bundleIdentifier)
    }
}
