//
//  FakeAIPreferencesStore.swift
//  BelloHubTests
//

@testable import BelloHub

/// Preferences kept in memory, counting the saves.
@MainActor
final class FakeAIPreferencesStore: AIPreferencesStoring {
    var stored: AIPreferences
    private(set) var saveCount = 0

    init(_ stored: AIPreferences = AIPreferences()) {
        self.stored = stored
    }

    func load() -> AIPreferences { stored }

    func save(_ preferences: AIPreferences) {
        stored = preferences
        saveCount += 1
    }
}
