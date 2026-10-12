//
//  VisitDetailViewModelTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@MainActor
@Suite("VisitDetailViewModel", .serialized)
struct VisitDetailViewModelTests {
    private struct World {
        let repository: any ClientRecordRepository
        let model: VisitDetailViewModel
        let client: Client
        let clock: MutableClock
    }

    private func makeWorld(_ record: (UUID) -> TreatmentRecord) async throws -> World {
        let clock = MutableClock()
        let repository: any ClientRecordRepository = InMemoryClientRecordRepository(clock: { clock.now })
        let vault = VaultService(repository: repository)
        let profile = ProfileService(vault: vault)
        let client = makeClient()
        try await repository.save(client)
        let stored = record(client.id)
        try await repository.save(stored)
        let model = VisitDetailViewModel(recordID: stored.id, vault: vault, profile: profile, now: { clock.now })
        await model.loadAsync()
        return World(repository: repository, model: model, client: client, clock: clock)
    }

    @Test("An open record is completed directly; a template field added later reads as an answer")
    func completeOpenRecord() async throws {
        let world = try await makeWorld { TreatmentRecord(clientID: $0, serviceName: "Glow", createdAt: TestClock.now) }
        world.model.beginCorrection(field: .standard(.reaction))
        world.model.draft?.newValue = "Slight redness"
        await world.model.saveCorrectionAsync()

        #expect(world.model.values?.value(.reaction) == "Slight redness")
        #expect(world.model.corrections.isEmpty, "an open record is edited, not corrected")
    }

    @Test("A locked record is corrected with a reason, and the original stays in the vault")
    func correctLockedRecord() async throws {
        let world = try await makeWorld {
            TreatmentRecord(clientID: $0, serviceName: "Glow", createdAt: TestClock.days(-3), aftercare: "Old")
        }
        world.model.beginCorrection(field: .standard(.aftercare))
        world.model.draft?.newValue = "New"
        await world.model.saveCorrectionAsync()
        #expect(world.model.draftProblem == .reasonMissing)

        world.model.draft?.reason = "Typo"
        await world.model.saveCorrectionAsync()

        #expect(world.model.values?.value(.aftercare) == "New")
        #expect(world.model.record?.aftercare == "Old")
        #expect(world.model.trail.contains { if case .correction = $0.kind { true } else { false } })
    }

    @Test("An old record gets a visit day by a logged correction, never by guessing")
    func visitDayOnLockedRecord() async throws {
        let world = try await makeWorld {
            TreatmentRecord(clientID: $0, serviceName: "Glow", createdAt: TestClock.days(-30))
        }
        #expect(world.model.visitDate?.source == .writtenOnly)
        let day = TestClock.days(-32)

        #expect(world.model.visitDayProblem(day: day, reason: "") == .reasonMissing)
        #expect(world.model.visitDayProblem(day: TestClock.days(2), reason: "x") == .inFuture)
        #expect(await world.model.saveVisitDay(day, reason: "Wrote it two days late"))

        #expect(world.model.visitDate == RecordVisitDate(date: day, source: .recorded))
        #expect(world.model.record?.performedAt == nil, "the stored record is untouched")
    }

    @Test("A draft's visit day is stored on the record directly")
    func visitDayOnDraft() async throws {
        let world = try await makeWorld {
            TreatmentRecord(clientID: $0, serviceName: "Glow", createdAt: TestClock.now, status: .draft)
        }
        let day = TestClock.days(-1)
        #expect(!world.model.visitDayNeedsReason)
        #expect(await world.model.saveVisitDay(day, reason: ""))

        #expect(world.model.record?.performedAt == day)
        #expect(world.model.state == .draft)
    }

    @Test("Reusing a visit starts a new one for the same client and service, with the chosen parts")
    func reuse() async throws {
        let world = try await makeWorld {
            TreatmentRecord(clientID: $0, appointmentID: UUID(), serviceName: "Glow", createdAt: TestClock.days(-9),
                            technique: "Peel")
        }
        let request = try #require(world.model.reuseRequest(parts: [.technique]))

        #expect(request.clientID == world.client.id)
        #expect(request.appointmentID == nil)
        #expect(request.recordID == nil)
        #expect(request.base == VisitReuse(recordID: world.model.recordID, parts: [.technique]))
    }
}
