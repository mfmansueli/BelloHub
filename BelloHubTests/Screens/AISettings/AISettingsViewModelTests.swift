//
//  AISettingsViewModelTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@MainActor
@Suite("AISettingsViewModel")
struct AISettingsViewModelTests {
    private func makeModel(
        stored: AIPreferences = AIPreferences(), availability: VoiceAvailability = .notAvailableYet
    ) -> (AISettingsViewModel, FakeAIPreferencesStore) {
        let store = FakeAIPreferencesStore(stored)
        let voice = FakeVoiceCapture()
        voice.availabilityAnswer = availability
        return (AISettingsViewModel(store: store, voice: voice, locale: Locale(identifier: "en")), store)
    }

    @Test("Review before saving is locked on and cloud help does not exist, whatever was stored")
    func lockedRules() {
        let (model, _) = makeModel()
        #expect(model.preferences.reviewRequired)
        #expect(model.preferences.cloudHelpAvailable == false)
    }

    @Test("Nothing stored means the defaults: voice, assistant and deleting recordings on")
    func defaults() {
        let (model, _) = makeModel()
        #expect(model.voiceEnabled)
        #expect(model.aiEnabled)
        #expect(model.deleteRecordings)
    }

    @Test("Changing a switch saves it; setting the same value saves nothing")
    func saves() {
        let (model, store) = makeModel()
        model.voiceEnabled = false
        #expect(store.stored.voiceEnabled == false)
        #expect(store.saveCount == 1)
        model.voiceEnabled = false
        #expect(store.saveCount == 1)
        model.deleteRecordings = false
        model.aiEnabled = false
        let expected = AIPreferences(voiceEnabled: false, aiEnabled: false, deleteRecordingsAfterOrganizing: false)
        #expect(store.stored == expected)
    }

    @Test("What was saved comes back when the screen opens", arguments: [true, false])
    func restores(voiceEnabled: Bool) {
        let (model, _) = makeModel(stored: AIPreferences(voiceEnabled: voiceEnabled))
        #expect(model.voiceEnabled == voiceEnabled)
    }

    @Test("The status follows what the voice technology says", arguments: [
        VoiceAvailability.available, .notAvailableYet, .permissionDenied, .languageUnsupported
    ])
    func status(availability: VoiceAvailability) async {
        let (model, _) = makeModel(availability: availability)
        #expect(model.availability == nil)
        await model.loadAsync()
        #expect(model.availability == availability)
    }
}
