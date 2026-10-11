//
//  PushAlertStringsTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

/// The server sends only a `loc-key` (API.md section 7) and iOS resolves it from the app's bundle, also for a closed
/// app; a key without a string reaches the lock screen as "push.booking.new". The keys come from the backend's
/// published list (`firebase/functions/contracts/push-keys.json`, copied into the test bundle by
/// `scripts/sync-server-contract.sh`), so a key added on the server fails here until the app carries it.
@Suite("Push alert strings")
struct PushAlertStringsTests {
    private final class BundleToken {}

    /// The fourteen localizations (docs/07-LOCALIZATION.md section 1), as the compiled `.lproj` folders name them.
    private static let localizations = [
        "pt-BR", "pt-PT", "es-MX", "es-419", "es", "en", "en-GB", "it", "fr", "de", "tr", "id", "hi", "ar"
    ]

    @Test("Every key the server sends has a placeholder-free text in all fourteen localizations")
    func everyKeyIsLocalized() throws {
        let keys = try serverKeys()
        #expect(keys.count >= 8)
        for localization in Self.localizations {
            let bundle = try localizedBundle(localization)
            for key in keys {
                let text = bundle.localizedString(forKey: key, value: nil, table: nil)
                #expect(text != key, "\(localization): \(key) has no string")
                #expect(!text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, "\(localization): \(key)")
                #expect(!text.contains("%"), "\(localization): \(key) has a placeholder; the server sends no arguments")
                #expect(!PushPresentation.isUnresolvedKey(text), "\(localization): \(key)")
            }
        }
    }

    @Test("Every booking event has its own text, so she can tell what happened")
    func bookingEventsDiffer() throws {
        let events = ["push.booking.new", "push.booking.request", "push.booking.moved", "push.booking.cancelled"]
        for localization in Self.localizations {
            let bundle = try localizedBundle(localization)
            let texts = events.map { bundle.localizedString(forKey: $0, value: nil, table: nil) }
            #expect(Set(texts).count == events.count, "\(localization)")
        }
    }

    @Test("A raw push key is hidden in the foreground, a resolved text is shown")
    func foregroundPresentation() {
        #expect(PushPresentation.options(forBody: "push.booking.new").isEmpty)
        #expect(PushPresentation.options(forBody: "New booking confirmed through your page") == [.banner, .list, .sound])
        #expect(!PushPresentation.isUnresolvedKey("push. Something readable"))
    }

    // MARK: - Helpers

    private func serverKeys() throws -> [String] {
        let url = try #require(Bundle(for: BundleToken.self).url(forResource: "push-keys", withExtension: "json"))
        let object = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any]
        return try #require(object?["keys"] as? [String])
    }

    private func localizedBundle(_ localization: String) throws -> Bundle {
        let path = try #require(Bundle.main.path(forResource: localization, ofType: "lproj"), "\(localization).lproj")
        return try #require(Bundle(path: path))
    }
}
