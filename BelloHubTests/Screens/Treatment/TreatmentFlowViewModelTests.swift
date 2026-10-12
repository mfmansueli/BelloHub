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
        request: ((UUID) -> TreatmentFlowRequest)? = nil,
        voice: FakeVoiceCapture = FakeVoiceCapture(),
        structuring: any RecordStructuring = UnavailableRecordStructuring(),
        photoProcessing: any PhotoProcessing = FakePhotoProcessing(),
        withPhotoConsent: Bool = false,
        seed: (any ClientRecordRepository, Client) async throws -> Void = { _, _ in }
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
        try await seed(world.repository, client)
        let recordID = UUID()
        let model = TreatmentFlowViewModel(
            request: request?(client.id) ?? TreatmentFlowRequest(clientID: client.id), repository: world.repository,
            profile: world.profile, voice: voice, structuring: structuring, photoProcessing: photoProcessing,
            names: .init(serviceFallback: "Treatment", notes: "Observations", recommendation: "Recommendation"),
            autosaveDelay: .zero, now: { TestClock.now }, makeID: { recordID }
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
            names: .init(serviceFallback: "Treatment", notes: "Observations", recommendation: "Recommendation")
        )
        await model.load()
        #expect(model.loadState == .clientMissing)
    }

    // MARK: - Drafts and finalizing

    @Test("Typing saves a draft on its own; finalizing turns the same record into the finalized one")
    func draftThenFinalize() async throws {
        let world = try await makeWorld()
        world.model.set("Skin a little sensitive.", for: TreatmentFormField.notesKey)
        await world.model.autosaveNow()
        let draft = try #require(try await world.repository.records(for: world.client.id).first)
        #expect(draft.isDraft && draft.notes == "Skin a little sensitive.")
        #expect(!world.model.hasUnsavedWork)

        await world.model.finalize()
        let stored = try await world.repository.records(for: world.client.id)
        #expect(stored.map(\.id) == [draft.id], "the draft became the record: still one record")
        #expect(stored.first?.status == .finalized)
        #expect(stored.first?.aiAssisted == false && stored.first?.source == .manual)
        #expect(world.model.path == [.saved])
    }

    @Test("Opening and closing the form with nothing written stores nothing")
    func emptyDraftIsNeverStored() async throws {
        let world = try await makeWorld()
        world.model.draftChanged()
        await world.model.autosaveNow()
        #expect(try await world.repository.records(for: world.client.id).isEmpty)
        await world.model.finalize()
        #expect(world.model.issues == [.nothingToSave] && world.model.showsValidation)
        #expect(try await world.repository.records(for: world.client.id).isEmpty)
    }

    @Test("A photo first, before any field: the draft is stored and the photo is tied to it by id")
    func photoBeforeTheForm() async throws {
        let world = try await makeWorld()
        let added = await world.model.addPhoto(Data([1, 2, 3]), kind: .before)
        #expect(added)
        let record = try #require(try await world.repository.records(for: world.client.id).first)
        #expect(record.isDraft)
        let photos = try await world.repository.photos(for: world.client.id)
        #expect(photos.map(\.recordID) == [record.id])
        await world.model.finalize()
        #expect(world.model.savedRecord?.status == .finalized, "a visit documented with photos only is complete")
    }

    @Test("A draft left behind is continued after a relaunch, with its answers, visit day and photos")
    func recoverDraftAfterRelaunch() async throws {
        let first = try await makeWorld()
        first.model.set("Half written", for: TreatmentFormField.notesKey)
        first.model.setPerformedAt(TestClock.days(-1))
        await first.model.addPhoto(Data([7]), kind: .after)
        await first.model.autosaveNow()
        let recordID = first.model.recordID

        // A new flow, as after the app was closed: it opens the stored draft by id.
        let reopened = TreatmentFlowViewModel(
            request: TreatmentFlowRequest(clientID: first.client.id, recordID: recordID),
            repository: first.repository, profile: first.model.profile,
            names: .init(serviceFallback: "Treatment", notes: "Observations", recommendation: "Recommendation"),
            autosaveDelay: .zero, now: { TestClock.now }
        )
        await reopened.load()
        #expect(reopened.draft.value(for: TreatmentFormField.notesKey) == "Half written")
        #expect(reopened.performedAt == TestClock.days(-1))
        #expect(reopened.photos.count == 1)
        #expect(reopened.savedRecord?.isDraft == true)
    }

    @Test("Reopening a visit for the same appointment opens its record, never a second one")
    func oneRecordPerAppointment() async throws {
        let appointment = makeAppointment(clientID: UUID(), daysFromNow: 0)
        var existingID: UUID?
        let world = try await makeWorld(
            request: { TreatmentFlowRequest(clientID: $0, appointmentID: appointment.id) },
            seed: { repository, client in
                var owned = appointment
                owned.clientID = client.id
                try await repository.save(owned)
                let record = TreatmentRecord(clientID: client.id, appointmentID: appointment.id, serviceName: "Glow",
                                             createdAt: TestClock.now, status: .draft, technique: "Peel")
                existingID = record.id
                try await repository.save(record)
            }
        )
        #expect(world.model.recordID == existingID)
        #expect(world.model.savedRecord?.technique == "Peel")
        world.model.set("More", for: TreatmentFormField.notesKey)
        await world.model.autosaveNow()
        #expect(try await world.repository.records(for: world.client.id).count == 1)
    }

    @Test("The visit day is its own field, different from the day the record is written")
    func visitDay() async throws {
        let world = try await makeWorld()
        world.model.setPerformedAt(TestClock.days(-3))
        world.model.set("Old visit written today", for: TreatmentFormField.notesKey)
        await world.model.finalize()
        let saved = try #require(world.model.savedRecord)
        #expect(saved.performedAt == TestClock.days(-3))
        #expect(saved.createdAt == TestClock.now)
        world.model.setPerformedAt(TestClock.days(5))
        #expect(world.model.performedAt <= TestClock.now, "a future visit day is not taken")
    }

    @Test("A draft she does not want is deleted with its photos; a finalized record is not")
    func discardDraft() async throws {
        let world = try await makeWorld()
        await world.model.addPhoto(Data([1]), kind: .before)
        #expect(await world.model.discardDraft())
        #expect(try await world.repository.records(for: world.client.id).isEmpty)
        #expect(try await world.repository.photos(for: world.client.id).isEmpty)
    }

    @Test("Using a past visit as the base copies only the chosen parts and never the result or the photos")
    func baseFromPastVisit() async throws {
        var sourceID = UUID()
        let world = try await makeWorld(
            request: { TreatmentFlowRequest(clientID: $0, base: VisitReuse(recordID: sourceID, parts: [.technique])) },
            seed: { repository, client in
                let source = TreatmentRecord(clientID: client.id, serviceName: "Glow", createdAt: TestClock.days(-30),
                                             result: .reaction, notes: "Old note", technique: "Peel",
                                             reaction: "Redness")
                sourceID = source.id
                try await repository.save(source)
            }
        )
        #expect(world.model.draft.value(for: TreatmentFormField.reactionKey).isEmpty)
        #expect(world.model.draft.value(for: TreatmentFormField.notesKey).isEmpty)
        #expect(world.model.draft.result == nil)
        #expect(world.model.photos.isEmpty)
        #expect(try await world.repository.records(for: world.client.id).count == 1, "nothing saved until a change")
    }

    @Test("Reaction and what to remember are saved in their own places")
    func reactionAndReminder() async throws {
        let world = try await makeWorld()
        world.model.set("Slight redness", for: TreatmentFormField.reactionKey)
        world.model.set("Try curl D", for: TreatmentFormField.reminderKey)
        await world.model.finalize()
        #expect(world.model.savedRecord?.reaction == "Slight redness")
        #expect(world.model.savedRecord?.nextVisitReminder == "Try curl D")
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
        #expect(world.model.path.isEmpty, "the kept answers go back to the form, to be read and finalized")
        let saved = try #require(world.model.savedRecord)
        #expect(saved.isDraft && saved.aiAssisted && saved.source == .voice)
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
        #expect(world.model.path.isEmpty)
        #expect(world.model.draft.value(for: TreatmentFormField.notesKey) == voice.transcript)
        await world.model.finalize()
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
        #expect(world.model.path.isEmpty)
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
        world.model.set("x", for: TreatmentFormField.notesKey)
        await world.model.finalize()
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

    @Test("The interval of the next visit is written into the record as its note")
    func nextSessionSuggestion() async throws {
        let world = try await makeWorld()
        world.model.setNextWeeks(6)
        await world.model.finalize()
        let stored = try await world.repository.records(for: world.client.id).first
        #expect(stored?.nextSessionSuggestion == world.model.formatters.weeks(6))
    }
}
