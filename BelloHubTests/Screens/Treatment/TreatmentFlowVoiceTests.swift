//
//  TreatmentFlowVoiceTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@MainActor
@Suite("TreatmentFlowViewModel voice", .serialized)
struct TreatmentFlowVoiceTests {
    // MARK: - Voice path

    @Test("Voice listens, organizes, and shows a review; nothing is saved and aiAssisted waits for her decisions")
    func voicePathThroughReview() async throws {
        let voice = FakeVoiceCapture()
        let world = try await TreatmentFlowWorld.make(
            voice: voice, structuring: FakeRecordStructuring(draft: StructuredRecordDraft(
                values: ["notes": "Skin a little sensitive."], summary: nil
            ))
        )
        world.model.startListening()
        #expect(world.model.path == [.listening] && world.model.isListening)
        await Wait.untilMain { world.model.transcript == voice.transcript }
        await world.model.finishListening()
        await Wait.untilMain { world.model.path == [.review] }
        #expect(world.model.proposals.map(\.field.key) == [TreatmentFormField.notesKey])
        #expect(try await world.repository.records(for: world.client.id).isEmpty)
        #expect(!world.model.canSaveReview, "a card is still pending")

        world.model.accept(TreatmentFormField.notesKey)
        #expect(world.model.canSaveReview)
        await world.model.saveReview()
        #expect(world.model.path.isEmpty, "the kept answers go back to the form, to be read and finalized")
        let saved = try #require(world.model.savedRecord)
        #expect(saved.isDraft && saved.aiAssisted && saved.source == .voice)
        #expect(saved.notes == "Skin a little sensitive.")
    }

    @Test("When she drops every card the saved record is not marked as AI-assisted, or not saved at all")
    func droppingEverything() async throws {
        let world = try await TreatmentFlowWorld.make(
            voice: FakeVoiceCapture(),
            structuring: FakeRecordStructuring(draft: StructuredRecordDraft(values: ["notes": "x"], summary: nil))
        )
        world.model.startListening()
        await Wait.untilMain { !world.model.transcript.isEmpty }
        await world.model.finishListening()
        await Wait.untilMain { world.model.path == [.review] }
        world.model.drop(TreatmentFormField.notesKey)
        #expect(world.model.reviewIsEmptyAfterDecisions)
        await world.model.saveReview()
        #expect(world.model.savedRecord == nil)
    }

    @Test("Without structuring, her words open the form as notes and the record says it came from voice")
    func transcriptBecomesNotes() async throws {
        let voice = FakeVoiceCapture()
        let world = try await TreatmentFlowWorld.make(voice: voice)
        world.model.startListening()
        await Wait.untilMain { world.model.transcript == voice.transcript }
        await world.model.finishListening()
        #expect(world.model.path.isEmpty)
        #expect(world.model.draft.value(for: TreatmentFormField.notesKey) == voice.transcript)
        await world.model.finalize()
        #expect(world.model.savedRecord?.source == .voice)
        #expect(world.model.savedRecord?.aiAssisted == false)
    }

    @Test("A failing structuring keeps her words and offers the way out")
    func structuringFailure() async throws {
        let world = try await TreatmentFlowWorld.make(
            voice: FakeVoiceCapture(), structuring: FakeRecordStructuring(draft: nil)
        )
        world.model.startListening()
        await Wait.untilMain { !world.model.transcript.isEmpty }
        await world.model.finishListening()
        await Wait.untilMain { world.model.failure == .organize }
        world.model.cancelOrganizing()
        #expect(world.model.path.isEmpty)
        #expect(!world.model.draft.value(for: TreatmentFormField.notesKey).isEmpty)
    }

    @Test("Voice does not start when it is not available")
    func noVoiceWhenUnavailable() async throws {
        let voice = FakeVoiceCapture()
        voice.availabilityAnswer = .permissionDenied
        let world = try await TreatmentFlowWorld.make(voice: voice)
        world.model.startListening()
        #expect(world.model.path.isEmpty && voice.startCount == 0)
    }
}
