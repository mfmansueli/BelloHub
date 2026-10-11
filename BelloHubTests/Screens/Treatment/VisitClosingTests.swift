//
//  VisitClosingTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

/// Closing a visit after the record (routine-a item 7): the rules, then the flow over a real in-memory vault.
@MainActor
@Suite("Visit closing", .serialized)
struct VisitClosingTests {
    // MARK: - Rules

    @Test("The steps are numbered 1 to 4 and a resumed flow opens on the first open step")
    func rules() {
        #expect(VisitClosingRules.position(of: .saved) == 1)
        #expect(VisitClosingRules.position(of: .photos) == 2)
        #expect(VisitClosingRules.position(of: .aftercare) == 3)
        #expect(VisitClosingRules.position(of: .nextSession) == 4)
        var closing = VisitClosing(id: UUID(), clientID: UUID(), serviceName: "Glow", recordCreatedAt: TestClock.now)
        closing.settled = [.photos]
        #expect(VisitClosingRules.resumePath(for: closing) == [.saved, .aftercare])
        #expect(VisitClosingRules.next(after: .photos, in: closing) == .aftercare)
        closing.settled = [.photos, .aftercare, .nextVisit]
        #expect(VisitClosingRules.resumePath(for: closing) == [.saved])
        #expect(closing.isComplete)
    }

    // MARK: - Flow

    private struct World {
        let model: TreatmentFlowViewModel
        let repository: any ClientRecordRepository
        let queue: FollowUpQueueService
        let profile: ProfileService
        let client: Client
        let suite: String
    }

    private func makeWorld(now: @escaping @Sendable () -> Date = { TestClock.now }) async throws -> World {
        let world = try await ClientsWorld.make()
        let client = makeClient(name: "Ana Costa")
        _ = try await world.repository.save(client)
        let suite = "closing-\(UUID().uuidString)"
        let queue = FollowUpQueueService(
            defaults: UserDefaults(suiteName: suite) ?? .standard, vault: VaultService(repository: world.repository),
            now: now
        )
        queue.start(userID: "maria")
        let recordID = UUID()
        let model = TreatmentFlowViewModel(
            request: TreatmentFlowRequest(clientID: client.id), repository: world.repository, profile: world.profile,
            closings: queue, fallbackServiceName: "Treatment", notesName: "Observations",
            recommendationName: "Recommendation", now: now, makeID: { recordID }
        )
        await model.load()
        return World(
            model: model, repository: world.repository, queue: queue, profile: world.profile, client: client,
            suite: suite
        )
    }

    private func saveRecord(_ world: World) async {
        world.model.draft.set("Calm skin.", for: TreatmentFormField.notesKey)
        await world.model.saveForm()
    }

    @Test("Saving starts the closing; each step moves on; Finish later leaves it in the queue's store")
    func walk() async throws {
        let world = try await makeWorld()
        defer { UserDefaults.standard.removePersistentDomain(forName: world.suite) }
        await saveRecord(world)
        let recordID = try #require(world.model.savedRecord?.id)
        #expect(world.model.closing?.openSteps == [.photos, .aftercare, .nextVisit])

        world.model.continueClosing()
        #expect(world.model.path == [.saved, .photos])
        #expect(world.model.advance(from: .photos))
        #expect(world.model.path == [.saved, .aftercare])

        world.model.finishLater()
        let stored = try #require(world.queue.closing(for: recordID))
        #expect(stored.isDeferred && stored.openSteps == [.aftercare, .nextVisit])
    }

    @Test("Resuming opens the same record on the first open step and never makes a second record")
    func resume() async throws {
        let world = try await makeWorld()
        defer { UserDefaults.standard.removePersistentDomain(forName: world.suite) }
        await saveRecord(world)
        let record = try #require(world.model.savedRecord)
        world.model.continueClosing()
        world.model.advance(from: .photos)
        world.model.finishLater()

        let resumed = TreatmentFlowViewModel(
            request: TreatmentFlowRequest(clientID: world.client.id, resumeRecordID: record.id),
            repository: world.repository, profile: world.profile, closings: world.queue,
            fallbackServiceName: "Treatment", notesName: "Observations", recommendationName: "Recommendation",
            now: { TestClock.now }, makeID: { UUID() }
        )
        await resumed.load()

        #expect(resumed.savedRecord?.id == record.id && resumed.recordID == record.id)
        #expect(resumed.path == [.saved, .aftercare])
        #expect(try await world.repository.records(for: world.client.id).count == 1)
        #expect(resumed.advance(from: .aftercare))
        #expect(!resumed.advance(from: .nextVisit))
        #expect(world.queue.closing(for: record.id)?.isComplete == true)
    }

    @Test("Aftercare is written into the record only while it can be edited")
    func aftercareRespectsTheLock() async throws {
        let clock = MutableClock()
        let world = try await makeWorld(now: { clock.now })
        defer { UserDefaults.standard.removePersistentDomain(forName: world.suite) }
        await saveRecord(world)
        let record = try #require(world.model.savedRecord)

        #expect(await world.model.saveAftercare("Avoid sun today."))
        #expect(try await world.repository.record(id: record.id)?.aftercare == "Avoid sun today.")

        clock.advance(by: RecordLockPolicy.lockInterval + 60)
        #expect(!world.model.isRecordEditable)
        #expect(!(await world.model.saveAftercare("Changed after the lock.")))
        #expect(!(await world.model.saveSuggestion(formatters: world.model.formatters)))
        #expect(try await world.repository.record(id: record.id)?.aftercare == "Avoid sun today.")
    }
}
