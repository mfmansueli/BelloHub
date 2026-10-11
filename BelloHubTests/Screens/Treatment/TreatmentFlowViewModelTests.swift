//
//  TreatmentFlowViewModelTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@MainActor
@Suite("TreatmentFlowViewModel", .serialized)
struct TreatmentFlowViewModelTests {
    private struct World {
        let model: TreatmentFlowViewModel
        let repository: any ClientRecordRepository
        let voice: FakeVoiceCapture
        let client: Client
    }

    private func makeWorld(
        voice: FakeVoiceCapture = FakeVoiceCapture(),
        structuring: any RecordStructuring = UnavailableRecordStructuring(),
        photoProcessing: any PhotoProcessing = FakePhotoProcessing(),
        withPhotoConsent: Bool = false
    ) async throws -> World {
        let world = try await ClientsWorld.make()
        let client = makeClient(name: "Ana Costa")
        _ = try await world.repository.save(client)
        if withPhotoConsent {
            try await world.repository.save(ConsentRecord(
                id: UUID(), clientID: client.id, kind: .photos, isSigned: true, signedAt: TestClock.days(-3),
                createdAt: TestClock.days(-3)
            ))
        }
        let recordID = UUID()
        let model = TreatmentFlowViewModel(
            request: TreatmentFlowRequest(clientID: client.id), repository: world.repository, profile: world.profile,
            voice: voice, structuring: structuring, photoProcessing: photoProcessing, fallbackServiceName: "Treatment",
            notesName: "Observations", recommendationName: "Recommendation", now: { TestClock.now },
            makeID: { recordID }
        )
        await model.load()
        return World(model: model, repository: world.repository, voice: voice, client: client)
    }

    private func structuredDraft(_ model: TreatmentFlowViewModel) -> StructuredRecordDraft {
        StructuredRecordDraft(values: ["notes": "Skin a little sensitive."], summary: nil)
    }

    // MARK: - Opening

    @Test("The flow opens on her client with the notes field and no voice offer when voice is not available yet")
    func opensWithTheManualPath() async throws {
        let voice = FakeVoiceCapture()
        voice.availabilityAnswer = .notAvailableYet
        let world = try await makeWorld(voice: voice)
        #expect(world.model.loadState == .ready)
        #expect(world.model.client?.name == "Ana Costa")
        #expect(world.model.fields.first?.key == TreatmentFormField.notesKey)
        #expect(world.model.registerOffer == .manualOnly(.notAvailableYet))
        #expect(world.model.serviceName == "Treatment")
    }

    @Test("A client who is gone is said, not crashed on")
    func clientMissing() async throws {
        let world = try await ClientsWorld.make()
        let model = TreatmentFlowViewModel(
            request: TreatmentFlowRequest(clientID: UUID()), repository: world.repository, profile: world.profile,
            fallbackServiceName: "Treatment", notesName: "Observations", recommendationName: "Recommendation"
        )
        await model.load()
        #expect(model.loadState == .clientMissing)
    }

    // MARK: - Manual path

    @Test("Saving the manual form writes one record, says it is not AI-assisted, and moves to Saved")
    func savesTheManualForm() async throws {
        let world = try await makeWorld()
        world.model.draft.set("Skin a little sensitive.", for: TreatmentFormField.notesKey)
        await world.model.saveForm()
        let saved = try #require(world.model.savedRecord)
        #expect(!saved.aiAssisted && saved.source == .manual && saved.notes == "Skin a little sensitive.")
        #expect(world.model.path == [.saved])
        let stored = try await world.repository.records(for: world.client.id)
        #expect(stored.map(\.id) == [saved.id])
        #expect(!world.model.hasUnsavedWork)
    }

    @Test("An empty form is not saved and the form says why")
    func refusesAnEmptyForm() async throws {
        let world = try await makeWorld()
        await world.model.saveForm()
        #expect(world.model.savedRecord == nil && world.model.showsValidation)
        #expect(world.model.issues == [.nothingToSave])
        #expect(try await world.repository.records(for: world.client.id).isEmpty)
    }

    @Test("What she typed counts as unsaved work until it is saved")
    func unsavedWork() async throws {
        let world = try await makeWorld()
        #expect(!world.model.hasUnsavedWork)
        world.model.draft.set("x", for: TreatmentFormField.notesKey)
        #expect(world.model.hasUnsavedWork)
    }

    // MARK: - Voice path

    @Test("Voice listens, organizes, and shows a review; nothing is saved and aiAssisted waits for her decisions")
    func voicePathThroughReview() async throws {
        let voice = FakeVoiceCapture()
        let world = try await makeWorld(
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
        let saved = try #require(world.model.savedRecord)
        #expect(saved.aiAssisted && saved.source == .voice)
        #expect(saved.notes == "Skin a little sensitive.")
    }

    @Test("When she drops every card the saved record is not marked as AI-assisted, or not saved at all")
    func droppingEverything() async throws {
        let world = try await makeWorld(
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
        let world = try await makeWorld(voice: voice)
        world.model.startListening()
        await Wait.untilMain { world.model.transcript == voice.transcript }
        await world.model.finishListening()
        #expect(world.model.path == [.form])
        #expect(world.model.draft.value(for: TreatmentFormField.notesKey) == voice.transcript)
        await world.model.saveForm()
        #expect(world.model.savedRecord?.source == .voice)
        #expect(world.model.savedRecord?.aiAssisted == false)
    }

    @Test("A failing structuring keeps her words and offers the way out")
    func structuringFailure() async throws {
        let world = try await makeWorld(voice: FakeVoiceCapture(), structuring: FakeRecordStructuring(draft: nil))
        world.model.startListening()
        await Wait.untilMain { !world.model.transcript.isEmpty }
        await world.model.finishListening()
        await Wait.untilMain { world.model.failure == .organize }
        world.model.cancelOrganizing()
        #expect(world.model.path == [.form])
        #expect(!world.model.draft.value(for: TreatmentFormField.notesKey).isEmpty)
    }

    @Test("Voice does not start when it is not available")
    func noVoiceWhenUnavailable() async throws {
        let voice = FakeVoiceCapture()
        voice.availabilityAnswer = .permissionDenied
        let world = try await makeWorld(voice: voice)
        world.model.startListening()
        #expect(world.model.path.isEmpty && voice.startCount == 0)
    }

    // MARK: - Photos

    @Test("A photo is saved at once, private when no photo consent is signed")
    func photoWithoutConsent() async throws {
        let world = try await makeWorld()
        world.model.draft.set("x", for: TreatmentFormField.notesKey)
        await world.model.saveForm()
        let added = await world.model.addPhoto(Data([1, 2, 3]), kind: .before, visibility: .portfolio)
        #expect(added)
        let photo = try #require(world.model.photos.first)
        #expect(photo.photo.visibility == .professionalOnly && photo.photo.recordID == world.model.savedRecord?.id)
        #expect(try await world.repository.photos(for: world.client.id).count == 1)
        #expect(world.model.allowedVisibilities == [.professionalOnly])
    }

    @Test("With a signed photo consent the choices open up")
    func photoWithConsent() async throws {
        let world = try await makeWorld(withPhotoConsent: true)
        #expect(world.model.hasPhotoConsent)
        await world.model.addPhoto(Data([1]), kind: .after, visibility: .shareWithClient)
        #expect(world.model.photos.first?.photo.visibility == .shareWithClient)
        let id = try #require(world.model.photos.first?.id)
        await world.model.setVisibility(.portfolio, for: id)
        #expect(world.model.photos.first?.photo.visibility == .portfolio)
        await world.model.deletePhoto(id)
        #expect(world.model.photos.isEmpty)
    }

    @Test("A picture that cannot be used says so and saves nothing")
    func photoFailure() async throws {
        let world = try await makeWorld(photoProcessing: FakePhotoProcessing(fails: true))
        let added = await world.model.addPhoto(Data([1]), kind: .before)
        #expect(!added && world.model.failure == .photo)
        #expect(try await world.repository.photos(for: world.client.id).isEmpty)
    }

    // MARK: - Next session

    @Test("The suggestion is written into the record while it is still inside its 24 hours")
    func nextSessionSuggestion() async throws {
        let world = try await makeWorld()
        world.model.draft.set("x", for: TreatmentFormField.notesKey)
        await world.model.saveForm()
        world.model.nextWeeks = 6
        let saved = await world.model.saveSuggestion(formatters: world.model.formatters)
        #expect(saved && world.model.suggestionSaved)
        let stored = try await world.repository.records(for: world.client.id).first
        #expect(stored?.nextSessionSuggestion == world.model.formatters.weeks(6))
    }
}
