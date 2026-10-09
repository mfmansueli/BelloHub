//
//  UserDefaultsAIPreferencesStore.swift
//  BelloHub
//

import Foundation

/// Keeps `AIPreferences` in UserDefaults on this iPhone. They are settings, not clinical data.
@MainActor
final class UserDefaultsAIPreferencesStore: AIPreferencesStoring {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> AIPreferences {
        guard let data = defaults.data(forKey: DefaultsKey.aiPreferences),
              let saved = try? JSONDecoder().decode(AIPreferences.self, from: data) else { return AIPreferences() }
        return saved
    }

    func save(_ preferences: AIPreferences) {
        defaults.set(try? JSONEncoder().encode(preferences), forKey: DefaultsKey.aiPreferences)
    }
}
