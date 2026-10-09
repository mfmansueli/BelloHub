//
//  IncidentViewModelTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@MainActor
@Suite("IncidentViewModel", .serialized)
struct IncidentViewModelTests {
    private struct World {
        let model: IncidentViewModel
        let repository: any ClientRecordRepository
        let client: Client
    }

    private func makeWorld(appointmentID: UUID? = nil, records: [TreatmentRecord] = []) async throws -> World {
        let world = try await ClientsWorld.make()
        let client = makeClient(name: "Ana Costa")
        _ = try await world.repository.save(client)
        for var record in records {
            record.clientID = client.id
            try await world.repository.save(record)
        }
        let model = IncidentViewModel(
            clientID: client.id, appointmentID: appointmentID, vault: world.vault, now: { TestClock.now },
            makeID: { UUID(uuidString: "00000000-0000-4000-8000-000000000001") ?? UUID() },
            resolve: { $0.resolved(in: Locale(identifier: "en")) }
        )
        await model.loadAsync()
        return World(model: model, repository: world.repository, client: client)
    }

    @Test("The sheet opens on the form with the prototype's defaults")
    func opens() async throws {
        let model = try await makeWorld().model
        #expect(model.phase == .form)
        #expect(model.draft.symptoms == [.redness])
        #expect(model.draft.severity == .mild)
        #expect(model.canSave)
    }

    @Test("Opened from a visit it is already tied to that visit's record")
    func linksTheVisit() async throws {
        let appointment = UUID()
        let linked = makeRecord(appointmentID: appointment, createdAt: TestClock.days(-1))
        let other = makeRecord(createdAt: TestClock.days(-8))
        let model = try await makeWorld(appointmentID: appointment, records: [other, linked]).model
        #expect(model.draft.recordID == linked.id)
        #expect(model.visits.map(\.id) == [linked.id, other.id])
    }

    @Test("Opened from the profile it is not tied to any visit")
    func noVisitByDefault() async throws {
        let model = try await makeWorld(records: [makeRecord()]).model
        #expect(model.draft.recordID == nil)
    }

    @Test("Saving writes the incident to the vault, locked 24 hours later, and moves to the saved state")
    func saves() async throws {
        let world = try await makeWorld()
        let model = world.model
        let repository = world.repository
        let client = world.client
        model.toggle(.swelling)
        model.toggle(IncidentAction.coldCompress)
        model.draft.severity = .moderate
        model.draft.notes = "Appeared an hour later"
        await model.saveAsync()
        #expect(model.phase == .saved)
        let incidents = try await repository.incidents(for: client.id)
        #expect(incidents.count == 1)
        let incident = try #require(incidents.first)
        #expect(incident.severity == .moderate)
        #expect(incident.symptoms == "Redness, Swelling. Appeared an hour later")
        #expect(incident.actionTaken == "Cold compress, Advised client")
        #expect(incident.area == "Cheeks")
        #expect(incident.needsFollowUp)
        #expect(incident.lockedAt == TestClock.now.addingTimeInterval(24 * 3600))
    }

    @Test("With no symptom chosen it cannot be saved and writes nothing")
    func needsASymptom() async throws {
        let world = try await makeWorld()
        let model = world.model
        let repository = world.repository
        let client = world.client
        model.toggle(.redness)
        #expect(model.draft.symptoms.isEmpty)
        #expect(model.canSave == false)
        await model.saveAsync()
        #expect(model.phase == .form)
        #expect(try await repository.incidents(for: client.id).isEmpty)
    }

    @Test("Choosing a symptom twice takes it back")
    func toggles() async throws {
        let model = try await makeWorld().model
        model.toggle(.itching)
        #expect(model.draft.symptoms == [.redness, .itching])
        model.toggle(.itching)
        #expect(model.draft.symptoms == [.redness])
    }

    @Test("A client who is gone is said")
    func missing() async throws {
        let world = try await ClientsWorld.make()
        let model = IncidentViewModel(clientID: UUID(), appointmentID: nil, vault: world.vault)
        await model.loadAsync()
        #expect(model.phase == .missing)
    }

    @Test("A vault that cannot be opened fails with a message")
    func failed() async {
        let model = IncidentViewModel(clientID: UUID(), appointmentID: nil, vault: VaultService(repository: nil))
        await model.loadAsync()
        guard case .failed(let message) = model.phase else {
            Issue.record("expected a failure")
            return
        }
        #expect(!message.isEmpty)
    }
}
