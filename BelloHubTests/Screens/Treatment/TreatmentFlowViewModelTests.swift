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
    // MARK: - Opening

    @Test("The flow opens on her client with the notes field and no voice offer when voice is not available yet")
    func opensWithTheManualPath() async throws {
        let voice = FakeVoiceCapture()
        voice.availabilityAnswer = .notAvailableYet
        let world = try await TreatmentFlowWorld.make(voice: voice)
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
        let world = try await TreatmentFlowWorld.make()
        world.model.set("Skin a little sensitive.", for: TreatmentFormField.notesKey)
        await world.model.autosaveNow()
        let draft = try #require(try await world.repository.records(for: world.client.id).first)
        #expect(draft.isDraft && draft.notes == "Skin a little sensitive.")
        #expect(world.model.autosave == .saved(TestClock.now))

        await world.model.finalize()
        let stored = try await world.repository.records(for: world.client.id)
        #expect(stored.map(\.id) == [draft.id], "the draft became the record: still one record")
        #expect(stored.first?.status == .finalized)
        #expect(stored.first?.aiAssisted == false && stored.first?.source == .manual)
        #expect(world.model.path == [.saved])
    }

    @Test("Opening and closing the form with nothing written stores nothing")
    func emptyDraftIsNeverStored() async throws {
        let world = try await TreatmentFlowWorld.make()
        world.model.draftChanged()
        await world.model.autosaveNow()
        #expect(try await world.repository.records(for: world.client.id).isEmpty)
        await world.model.finalize()
        #expect(world.model.issues == [.nothingToSave] && world.model.showsValidation)
        #expect(try await world.repository.records(for: world.client.id).isEmpty)
    }

    @Test("A photo first, before any field: the draft is stored and the photo is tied to it by id")
    func photoBeforeTheForm() async throws {
        let world = try await TreatmentFlowWorld.make()
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
        let first = try await TreatmentFlowWorld.make()
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
        let world = try await TreatmentFlowWorld.make(
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
        let world = try await TreatmentFlowWorld.make()
        world.model.setPerformedAt(TestClock.days(-3))
        world.model.set("Old visit written today", for: TreatmentFormField.notesKey)
        await world.model.finalize()
        let saved = try #require(world.model.savedRecord)
        #expect(saved.performedAt == TestClock.days(-3))
        #expect(saved.createdAt == TestClock.now)
        world.model.setPerformedAt(TestClock.days(5))
        #expect(world.model.performedAt <= TestClock.now, "a future visit day is not taken")
    }

    @Test("A visit opened before its appointment starts takes today as the visit day, never a day to come")
    func visitDayNeverInTheFuture() async throws {
        var upcomingID = UUID()
        let world = try await TreatmentFlowWorld.make(
            request: { TreatmentFlowRequest(clientID: $0, appointmentID: upcomingID) },
            seed: { repository, client in
                let upcoming = makeAppointment(clientID: client.id, daysFromNow: 2, status: .confirmed)
                upcomingID = upcoming.id
                try await repository.save(upcoming)
            }
        )
        #expect(world.model.performedAt == TestClock.now)
    }

    @Test("The service's standard aftercare text alone is not a draft and cannot be finalized")
    func aftercarePrefillIsNotContent() async throws {
        let serviceID = UUID()
        let world = try await TreatmentFlowWorld.make(
            request: { TreatmentFlowRequest(clientID: $0, serviceID: serviceID) },
            seed: { repository, _ in
                try await repository.save(Service(id: serviceID, name: "Peel", durationMinutes: 30,
                                                  aftercareTemplate: "Rest for a day."))
            }
        )
        #expect(world.model.draft.value(for: TreatmentFormField.aftercareKey) == "Rest for a day.")
        await world.model.autosaveNow()
        #expect(try await world.repository.records(for: world.client.id).isEmpty)
        #expect(world.model.issues.contains(.nothingToSave))

        world.model.set("Rest for two days.", for: TreatmentFormField.aftercareKey)
        await world.model.autosaveNow()
        #expect(try await world.repository.records(for: world.client.id).count == 1)
    }

    @Test("A draft she does not want is deleted with its photos; a finalized record is not")
    func discardDraft() async throws {
        let world = try await TreatmentFlowWorld.make()
        await world.model.addPhoto(Data([1]), kind: .before)
        #expect(await world.model.discardDraft())
        #expect(try await world.repository.records(for: world.client.id).isEmpty)
        #expect(try await world.repository.photos(for: world.client.id).isEmpty)

        let finished = try await TreatmentFlowWorld.make()
        finished.model.set("Skin a little sensitive.", for: TreatmentFormField.notesKey)
        await finished.model.finalize()
        #expect(!(await finished.model.discardDraft()))
        #expect(try await finished.repository.records(for: finished.client.id).count == 1)
    }

    @Test("Using a past visit as the base copies only the chosen parts and never the result or the photos")
    func baseFromPastVisit() async throws {
        var sourceID = UUID()
        let world = try await TreatmentFlowWorld.make(
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
        await world.model.autosaveNow()
        #expect(try await world.repository.records(for: world.client.id).count == 1, "nothing saved until a change")
        #expect(!world.model.issues.contains(.nothingToSave), "a past visit repeated as it was can be finalized")
    }

    @Test("Reaction and what to remember are saved in their own places")
    func reactionAndReminder() async throws {
        let world = try await TreatmentFlowWorld.make()
        world.model.set("Slight redness", for: TreatmentFormField.reactionKey)
        world.model.set("Try curl D", for: TreatmentFormField.reminderKey)
        await world.model.finalize()
        #expect(world.model.savedRecord?.reaction == "Slight redness")
        #expect(world.model.savedRecord?.nextVisitReminder == "Try curl D")
    }

    // MARK: - Next session

    @Test("The interval of the next visit is written into the record as its note")
    func nextSessionSuggestion() async throws {
        let world = try await TreatmentFlowWorld.make()
        world.model.setNextWeeks(6)
        await world.model.finalize()
        let stored = try await world.repository.records(for: world.client.id).first
        #expect(stored?.nextSessionSuggestion == world.model.formatters.weeks(6))
    }

    @Test("A saved technique chip adds its line once and a second tap takes only that line out")
    func techniqueChips() async throws {
        let world = try await TreatmentFlowWorld.make()
        let key = "technique"
        world.model.set("Soft pressure", for: key)
        world.model.addTechnique("Classic lift", save: false, fieldKey: key)
        world.model.addTechnique("classic LIFT", save: false, fieldKey: key)
        #expect(world.model.draft.value(for: key) == "Soft pressure\nClassic lift")
        world.model.removeTechnique("Classic lift", fieldKey: key)
        #expect(world.model.draft.value(for: key) == "Soft pressure")
    }
}
