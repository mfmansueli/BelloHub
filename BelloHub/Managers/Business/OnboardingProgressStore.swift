//
//  OnboardingProgressStore.swift
//  BelloHub
//

import Foundation

/// Keeps one user's unfinished setup (`OnboardingProgress`, JSON) in `UserDefaults` under
/// `DefaultsKey.onboardingProgress.<userID>`, so the setup resumes after a relaunch. Cleared when the setup is saved.
@MainActor
final class OnboardingProgressStore {
    private let defaults: UserDefaults
    private let key: String

    init(defaults: UserDefaults, userID: String) {
        self.defaults = defaults
        key = DefaultsKey.onboardingProgress + "." + userID
    }

    /// The saved progress, or nil when there is none or it was written by an older version that no longer reads.
    func load() -> OnboardingProgress? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(OnboardingProgress.self, from: data)
    }

    func save(_ progress: OnboardingProgress) {
        guard let data = try? JSONEncoder().encode(progress) else { return }
        defaults.set(data, forKey: key)
    }

    func clear() {
        defaults.removeObject(forKey: key)
    }
}
