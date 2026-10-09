//
//  RepositoryClientMergeContractTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

/// Merging two profiles of the same person, on both vaults: the SwiftData one and the in-memory one must agree.
/// Everything that belongs to the merged profile moves to the kept one, the merged client is deleted, and the
/// registration ledger (D42) is never touched: a merge neither registers a client nor gives a free slot back.
@Suite("Repository contract: merging clients", .serialized)
struct RepositoryClientMergeContractTests {
    private let clock = MutableClock()
    private let start = TestClock.date("2026-09-30 15:00")

    private struct Seeded {
        let repository: any ClientRecordRepository
        let kept: Client
        let merged: Client
    }

    /// Two clients, each with one of everything.
    private func seeded(_ flavor: RepositoryFlavor) async throws -> Seeded {
        let repository = try flavor.make(clock: clock)
        var kept = Client(name: "Ana Costa", phoneE164: "+5511981234410", createdAt: clock.now)
        kept.sensitivities = ["Cheeks"]
        kept.importantNote = "Prefers mornings"
        var merged = Client(name: "Ana C.", email: "ana@example.com", createdAt: TestClock.days(-90))
        merged.sensitivities = ["cheeks", "Neck"]
        merged.importantNote = "Allergic to latex"
        try await repository.save(kept)
        try await repository.save(merged)
        try await populate(repository, for: kept)
        try await populate(repository, for: merged)
        return Seeded(repository: repository, kept: kept, merged: merged)
    }

    private func populate(_ repository: any ClientRecordRepository, for client: Client) async throws {
        try await repository.save(Appointment(
            clientID: client.id, serviceName: "Glow", startsAt: start, endsAt: start.addingTimeInterval(3_600),
            createdAt: start
        ))
        try await repository.save(TreatmentRecord(
            clientID: client.id, serviceName: "Glow", createdAt: start, notes: "n"
        ))
        let record = try #require(try await repository.records(for: client.id).first)
        try await repository.save(Incident(
            id: UUID(), clientID: client.id, recordID: record.id, occurredAt: start, severity: .mild,
            lockedAt: start.addingTimeInterval(86_400), needsFollowUp: false, symptoms: "s", area: nil,
            actionTaken: nil, followUp: nil
        ))
        try await repository.save(
            Photo(id: UUID(), clientID: client.id, recordID: record.id, takenAt: start, kind: .before,
                  visibility: .professionalOnly),
            data: PhotoData(image: Data([1, 2, 3]), thumbnail: Data([9]))
        )
        try await repository.save(HealthForm(
            id: UUID(), clientID: client.id, formVersion: 1, filledBy: .client, isForMinor: false, signedAt: start,
            importedFromItemID: nil, answers: ["allergies": .no], signatureImage: nil, guardianName: nil,
            minorName: nil
        ))
        try await repository.save(Consent(
            id: UUID(), clientID: client.id, kind: .treatment, signedAt: start, textVersion: "1", localeID: "pt-BR",
            typedSignature: "A", signatureImage: nil
        ))
        try await repository.save(SessionPlan(
            id: UUID(), clientID: client.id, name: "Plan", totalSessions: 6, intervalWeeks: 4, startDate: start,
            remindToRebook: true
        ))
    }

    // MARK: - What moves

    @Test("Everything of the merged profile moves to the kept one and the merged client is gone",
          arguments: RepositoryFlavor.allCases)
    func everythingMoves(flavor: RepositoryFlavor) async throws {
        let seed = try await seeded(flavor)
        let (repository, kept, merged) = (seed.repository, seed.kept, seed.merged)

        try await repository.mergeClient(keeping: kept.id, merging: merged.id)

        #expect(try await repository.client(id: merged.id) == nil)
        #expect(try await repository.appointments(for: kept.id).count == 2)
        #expect(try await repository.records(for: kept.id).count == 2)
        #expect(try await repository.incidents(for: kept.id).count == 2)
        #expect(try await repository.photos(for: kept.id).count == 2)
        #expect(try await repository.healthForms(for: kept.id).count == 2)
        #expect(try await repository.consents(for: kept.id).count == 2)
        #expect(try await repository.sessionPlans(for: kept.id).count == 2)
        #expect(try await repository.appointments(for: merged.id).isEmpty)
        #expect(try await repository.records(for: merged.id).isEmpty)
        #expect(try await repository.photos(for: merged.id).isEmpty)
        #expect(try await repository.allClients().map(\.id) == [kept.id])
    }

    @Test("Nobody else's data is touched", arguments: RepositoryFlavor.allCases)
    func otherClientsAreUntouched(flavor: RepositoryFlavor) async throws {
        let seed = try await seeded(flavor)
        let (repository, kept, merged) = (seed.repository, seed.kept, seed.merged)
        let bystander = Client(name: "Bia", createdAt: clock.now)
        try await repository.save(bystander)
        try await populate(repository, for: bystander)

        try await repository.mergeClient(keeping: kept.id, merging: merged.id)

        #expect(try await repository.client(id: bystander.id) != nil)
        #expect(try await repository.appointments(for: bystander.id).count == 1)
        #expect(try await repository.records(for: bystander.id).count == 1)
        #expect(try await repository.photos(for: bystander.id).count == 1)
    }

    @Test("A locked record moves with its lock and its corrections, and its photo bytes still open",
          arguments: RepositoryFlavor.allCases)
    func lockedRecordMovesIntact(flavor: RepositoryFlavor) async throws {
        let seed = try await seeded(flavor)
        let (repository, kept, merged) = (seed.repository, seed.kept, seed.merged)
        let record = try #require(try await repository.records(for: merged.id).first)
        clock.set(record.lockedAt.addingTimeInterval(60))
        let correction = RecordCorrection(
            id: UUID(), recordID: record.id, createdAt: clock.now, fieldKey: "notes", oldValue: "n", newValue: "m",
            reason: "r"
        )
        try await repository.addCorrection(correction)
        let photo = try #require(try await repository.photos(for: merged.id).first)

        try await repository.mergeClient(keeping: kept.id, merging: merged.id)

        let moved = try #require(try await repository.record(id: record.id))
        #expect(moved.clientID == kept.id)
        #expect(moved.lockedAt == record.lockedAt && moved.createdAt == record.createdAt)
        #expect(try await repository.corrections(for: record.id).map(\.id) == [correction.id])
        #expect(try await repository.photoData(id: photo.id) == PhotoData(image: Data([1, 2, 3]), thumbnail: Data([9])))
        await #expect(throws: VaultRepositoryError.recordLocked) {
            try await repository.save(moved)
        }
    }

    // MARK: - The merged client value

    @Test("The kept profile wins, the other fills the gaps, and the private notes and lists join",
          arguments: RepositoryFlavor.allCases)
    func combinedClient(flavor: RepositoryFlavor) async throws {
        let seed = try await seeded(flavor)
        let (repository, kept, merged) = (seed.repository, seed.kept, seed.merged)

        let result = try await repository.mergeClient(keeping: kept.id, merging: merged.id)

        let stored = try #require(try await repository.client(id: kept.id))
        #expect(stored == result)
        #expect(stored.name == "Ana Costa")
        #expect(stored.phoneE164 == "+5511981234410")
        #expect(stored.email == "ana@example.com")
        #expect(stored.sensitivities == ["Cheeks", "Neck"])
        #expect(stored.importantNote == "Prefers mornings\n\nAllergic to latex")
        #expect(stored.createdAt == TestClock.days(-90))
    }

    // MARK: - The ledger (D42)

    @Test("The ledger keeps both entries: a merge never registers a client and never frees a slot",
          arguments: RepositoryFlavor.allCases)
    func ledgerIsUntouched(flavor: RepositoryFlavor) async throws {
        let seed = try await seeded(flavor)
        let (repository, kept, merged) = (seed.repository, seed.kept, seed.merged)
        let before = try await repository.registrationLedger()

        try await repository.mergeClient(keeping: kept.id, merging: merged.id)

        let after = try await repository.registrationLedger()
        #expect(after == before)
        #expect(Set(after.map(\.clientID)) == [kept.id, merged.id])
        let quota = RegistrationQuota(ledgerCount: after.count, hasActivePlan: false)
        #expect(quota.used == 2)
    }

    // MARK: - Refusals

    @Test("A profile cannot be merged into itself, and a missing profile is not found, and nothing changes",
          arguments: RepositoryFlavor.allCases)
    func refusals(flavor: RepositoryFlavor) async throws {
        let seed = try await seeded(flavor)
        let (repository, kept, merged) = (seed.repository, seed.kept, seed.merged)

        await #expect(throws: VaultRepositoryError.notFound) {
            try await repository.mergeClient(keeping: kept.id, merging: kept.id)
        }
        await #expect(throws: VaultRepositoryError.notFound) {
            try await repository.mergeClient(keeping: kept.id, merging: UUID())
        }
        await #expect(throws: VaultRepositoryError.notFound) {
            try await repository.mergeClient(keeping: UUID(), merging: merged.id)
        }

        #expect(try await repository.allClients().count == 2)
        #expect(try await repository.appointments(for: merged.id).count == 1)
        #expect(try await repository.appointments(for: kept.id).count == 1)
    }

    // MARK: - Observation

    @Test("The client stream emits the merged list", arguments: RepositoryFlavor.allCases)
    func streamEmits(flavor: RepositoryFlavor) async throws {
        let seed = try await seeded(flavor)
        let (repository, kept, merged) = (seed.repository, seed.kept, seed.merged)
        let seen = Seen()
        let task = Task {
            for await list in repository.clients() { await seen.add(list.count) }
        }
        defer { task.cancel() }
        #expect(await Wait.until { await seen.last == 2 })

        try await repository.mergeClient(keeping: kept.id, merging: merged.id)

        #expect(await Wait.until { await seen.last == 1 })
    }

    private actor Seen {
        private(set) var last: Int?

        func add(_ count: Int) {
            last = count
        }
    }
}
