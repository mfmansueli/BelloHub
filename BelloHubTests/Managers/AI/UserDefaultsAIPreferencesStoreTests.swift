//
//  UserDefaultsAIPreferencesStoreTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@MainActor
@Suite("UserDefaultsAIPreferencesStore")
struct UserDefaultsAIPreferencesStoreTests {
    private func makeDefaults() -> (UserDefaults, String) {
        let suite = "ai-preferences-tests-\(UUID().uuidString)"
        return (UserDefaults(suiteName: suite) ?? .standard, suite)
    }

    @Test("Nothing saved gives the defaults")
    func defaults() {
        let (defaults, suite) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        #expect(UserDefaultsAIPreferencesStore(defaults: defaults).load() == AIPreferences())
    }

    @Test("What is saved is read back")
    func roundTrip() {
        let (defaults, suite) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = UserDefaultsAIPreferencesStore(defaults: defaults)
        let changed = AIPreferences(voiceEnabled: false, aiEnabled: true, deleteRecordingsAfterOrganizing: false)
        store.save(changed)
        #expect(UserDefaultsAIPreferencesStore(defaults: defaults).load() == changed)
    }

    @Test("Unreadable stored data falls back to the defaults")
    func garbage() {
        let (defaults, suite) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(Data("not json".utf8), forKey: DefaultsKey.aiPreferences)
        #expect(UserDefaultsAIPreferencesStore(defaults: defaults).load() == AIPreferences())
    }

    @Test("No stored value can turn off the review or turn on cloud help")
    func lockedRulesAreNotStored() throws {
        let json = #"""
        {"voiceEnabled":true,"aiEnabled":true,"deleteRecordingsAfterOrganizing":true,
         "reviewRequired":false,"cloudHelpAvailable":true}
        """#
        let data = Data(json.utf8)
        let decoded = try JSONDecoder().decode(AIPreferences.self, from: data)
        #expect(decoded.reviewRequired)
        #expect(decoded.cloudHelpAvailable == false)
        let encoded = try JSONEncoder().encode(AIPreferences())
        #expect(String(bytes: encoded, encoding: .utf8)?.contains("reviewRequired") == false)
    }
}
