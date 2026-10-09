//
//  AISettingsViewModel.swift
//  BelloHub
//

import Foundation
import Observation

/// State and actions of 7.5 AISettings: the assistant's on-device preferences and whether this iPhone can run it. The
/// two rules that are not a choice (review before saving, no cloud help) are read from `AIPreferences` and cannot be
/// changed from here.
@MainActor
@Observable
final class AISettingsViewModel {
    private(set) var preferences: AIPreferences
    private(set) var availability: VoiceAvailability?

    private let store: any AIPreferencesStoring
    private let voice: any VoiceCapturing
    private let locale: Locale

    init(store: any AIPreferencesStoring, voice: any VoiceCapturing, locale: Locale) {
        self.store = store
        self.voice = voice
        self.locale = locale
        preferences = store.load()
    }

    // MARK: - Derived

    var voiceEnabled: Bool {
        get { preferences.voiceEnabled }
        set { update { $0.voiceEnabled = newValue } }
    }

    var aiEnabled: Bool {
        get { preferences.aiEnabled }
        set { update { $0.aiEnabled = newValue } }
    }

    var deleteRecordings: Bool {
        get { preferences.deleteRecordingsAfterOrganizing }
        set { update { $0.deleteRecordingsAfterOrganizing = newValue } }
    }

    // MARK: - Actions

    func load() {
        Task { await loadAsync() }
    }

    func loadAsync() async {
        preferences = store.load()
        availability = await voice.availability(for: locale)
    }

    // MARK: - Private

    private func update(_ change: (inout AIPreferences) -> Void) {
        var changed = preferences
        change(&changed)
        guard changed != preferences else { return }
        preferences = changed
        store.save(changed)
    }
}
