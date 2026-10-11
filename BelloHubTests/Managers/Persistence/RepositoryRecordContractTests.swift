//
//  RepositoryRecordContractTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@Suite("Repository contract: records, lock, photos", .serialized)
struct RepositoryRecordContractTests {
    private let fixture = ContractFixture()
    private var clock: MutableClock { fixture.clock }

    private func seeded(_ flavor: RepositoryFlavor) throws -> (any ClientRecordRepository, Client) {
        try fixture.seeded(flavor)
    }

    // MARK: - The 24-hour lock

    private func record(_ client: Client) -> TreatmentRecord {
        TreatmentRecord(clientID: client.id, serviceName: "Glow", createdAt: clock.now, source: .voice,
                        aiAssisted: true, notes: "Sentinel-REC", technique: "t", productsUsed: ["serum"])
    }

    @Test("A record is editable until exactly 24 hours, then only corrections (23:59:59 vs 24:00:00)",
          arguments: RepositoryFlavor.allCases)
    func lockBoundary(flavor: RepositoryFlavor) async throws {
        let (repository, client) = try seeded(flavor)
        var treatment = record(client)
        try await repository.save(treatment)

        clock.advance(by: 86_399)
        treatment.notes = "edited before the lock"
        try await repository.save(treatment)
        #expect(try await repository.record(id: treatment.id)?.notes == "edited before the lock")

        clock.advance(by: 1)
        treatment.notes = "edited at the lock"
        await #expect(throws: VaultRepositoryError.recordLocked) { try await repository.save(treatment) }
        #expect(try await repository.record(id: treatment.id)?.notes == "edited before the lock")
    }

    @Test("An edit before the lock can never move the lock time", arguments: RepositoryFlavor.allCases)
    func editDoesNotMoveTheLock(flavor: RepositoryFlavor) async throws {
        let (repository, client) = try seeded(flavor)
        var treatment = record(client)
        try await repository.save(treatment)
        let original = treatment.lockedAt
        clock.advance(by: 3_600)
        treatment.lockedAt = treatment.lockedAt.addingTimeInterval(7 * 86_400)
        try await repository.save(treatment)

        #expect(try await repository.record(id: treatment.id)?.lockedAt == original)
    }

    // MARK: - Drafts

    @Test("A draft never locks, is never corrected, and its lock starts when it is finalized",
          arguments: RepositoryFlavor.allCases)
    func draftLifecycle(flavor: RepositoryFlavor) async throws {
        let (repository, client) = try seeded(flavor)
        var draft = TreatmentRecord(clientID: client.id, serviceName: "Glow", createdAt: clock.now, status: .draft,
                                    notes: "Sentinel-DRAFT")
        try await repository.save(draft)
        let created = clock.now

        clock.advance(by: 3 * 86_400)
        draft.notes = "still a draft three days later"
        try await repository.save(draft)
        let correction = RecordCorrection(id: UUID(), recordID: draft.id, createdAt: clock.now, fieldKey: "notes",
                                          oldValue: nil, newValue: "x", reason: "y")
        await #expect(throws: VaultRepositoryError.recordNotLocked) { try await repository.addCorrection(correction) }

        let finalizedAt = clock.now
        draft.finalize(at: finalizedAt.addingTimeInterval(30 * 86_400))
        try await repository.save(draft)
        let stored = try #require(try await repository.record(id: draft.id))
        #expect(stored.status == .finalized)
        #expect(stored.createdAt == created)
        #expect(stored.finalizedAt == finalizedAt, "the repository's clock, not the caller's, starts the lock")
        #expect(stored.lockedAt == finalizedAt.addingTimeInterval(86_400))
    }

    @Test("A finalized record never goes back to being a draft", arguments: RepositoryFlavor.allCases)
    func noReturnToDraft(flavor: RepositoryFlavor) async throws {
        let (repository, client) = try seeded(flavor)
        var treatment = record(client)
        try await repository.save(treatment)
        let lock = treatment.lockedAt
        treatment.status = .draft
        treatment.lockedAt = RecordLockPolicy.draftLockedAt
        try await repository.save(treatment)

        let stored = try #require(try await repository.record(id: treatment.id))
        #expect(stored.status == .finalized)
        #expect(stored.lockedAt == lock)
    }

    @Test("Corrections need a locked record, are ordered, and the same one twice is a no-op",
          arguments: RepositoryFlavor.allCases)
    func corrections(flavor: RepositoryFlavor) async throws {
        let (repository, client) = try seeded(flavor)
        let treatment = record(client)
        try await repository.save(treatment)
        let first = RecordCorrection(id: UUID(), recordID: treatment.id, createdAt: clock.now, fieldKey: "notes",
                                     oldValue: "Sentinel-OLD", newValue: "Sentinel-NEW", reason: "Sentinel-WHY")

        await #expect(throws: VaultRepositoryError.recordNotLocked) { try await repository.addCorrection(first) }

        clock.advance(by: 86_400)
        try await repository.addCorrection(first)
        try await repository.addCorrection(first)
        clock.advance(by: 60)
        let second = RecordCorrection(id: UUID(), recordID: treatment.id, createdAt: clock.now, fieldKey: "aftercare",
                                      oldValue: nil, newValue: "x", reason: nil)
        try await repository.addCorrection(second)

        let stored = try await repository.corrections(for: treatment.id)
        #expect(stored.map(\.id) == [first.id, second.id])
        #expect(stored.first?.oldValue == "Sentinel-OLD")
        #expect(stored.first?.reason == "Sentinel-WHY")
    }

    @Test("A correction to a record that does not exist is refused", arguments: RepositoryFlavor.allCases)
    func correctionToNothing(flavor: RepositoryFlavor) async throws {
        let repository = try flavor.make(clock: clock)
        let orphan = RecordCorrection(id: UUID(), recordID: UUID(), createdAt: clock.now, fieldKey: "notes",
                                      oldValue: nil, newValue: nil, reason: nil)

        await #expect(throws: VaultRepositoryError.notFound) { try await repository.addCorrection(orphan) }
    }

    @Test("An incident locks the same way", arguments: RepositoryFlavor.allCases)
    func incidentLock(flavor: RepositoryFlavor) async throws {
        let (repository, client) = try seeded(flavor)
        var incident = Incident(id: UUID(), clientID: client.id, recordID: nil, occurredAt: clock.now, severity: .mild,
                                lockedAt: RecordLockPolicy.lockedAt(createdAt: clock.now), needsFollowUp: true,
                                symptoms: "Sentinel-SYMPTOMS", area: "cheeks", actionTaken: "cooled", followUp: nil)
        try await repository.save(incident)
        incident.symptoms = "edited"
        try await repository.save(incident)

        clock.advance(by: 86_400)
        incident.symptoms = "too late"
        await #expect(throws: VaultRepositoryError.recordLocked) { try await repository.save(incident) }
        #expect(try await repository.incidents(for: client.id).first?.symptoms == "edited")
    }

    // MARK: - Forms, consents, plans, photos

    @Test("A health form from the mailbox is imported once per item, even if the app crashed before acknowledging",
          arguments: RepositoryFlavor.allCases)
    func importIsIdempotent(flavor: RepositoryFlavor) async throws {
        let (repository, client) = try seeded(flavor)
        func form(itemID: String?) -> HealthForm {
            HealthForm(id: UUID(), clientID: client.id, formVersion: 2, filledBy: .client, isForMinor: false,
                       signedAt: clock.now, importedFromItemID: itemID, answers: ["allergies": .text("Sentinel-ANS")],
                       minorName: nil)
        }

        #expect(try await repository.importHealthForm(form(itemID: "item-1")) == true)
        #expect(try await repository.importHealthForm(form(itemID: "item-1")) == false)
        #expect(try await repository.importHealthForm(form(itemID: "item-2")) == true)
        #expect(try await repository.healthForms(for: client.id).count == 2)
        #expect(try await repository.healthForms(for: client.id).first?.answers["allergies"] == .text("Sentinel-ANS"))
    }

    @Test("Photos store the bytes and the thumbnail, and deleting removes them", arguments: RepositoryFlavor.allCases)
    func photos(flavor: RepositoryFlavor) async throws {
        let (repository, client) = try seeded(flavor)
        let photo = Photo(id: UUID(), clientID: client.id, recordID: nil, takenAt: clock.now, kind: .after,
                          visibility: .shareWithClient)
        let image = Data((0..<2_000).map { UInt8($0 % 251) })
        let bytes = PhotoData(image: image, thumbnail: Data((0..<50).map(UInt8.init)))
        try await repository.save(photo, data: bytes)

        #expect(try await repository.photoData(id: photo.id) == bytes)
        #expect(try await repository.photos(for: client.id).first?.visibility == .shareWithClient)
        try await repository.deletePhoto(id: photo.id)
        await #expect(throws: VaultRepositoryError.notFound) { _ = try await repository.photoData(id: photo.id) }
    }

    @Test("Consent records and session plans round-trip, with the document, and a record can be deleted",
          arguments: RepositoryFlavor.allCases)
    func consentsAndPlans(flavor: RepositoryFlavor) async throws {
        let (repository, client) = try seeded(flavor)
        let consent = ConsentRecord(
            id: UUID(), clientID: client.id, kind: .photos, isSigned: true, signedAt: clock.now, createdAt: clock.now,
            label: "Sentinel-LABEL", note: "Sentinel-NOTE",
            document: ConsentDocument(
                kind: .photo, fileName: nil, contentType: "public.jpeg", data: Data([1, 2, 3]), thumbnail: Data([9])
            )
        )
        let unsigned = ConsentRecord(
            id: UUID(), clientID: client.id, kind: .other, isSigned: false, signedAt: nil,
            createdAt: clock.now.addingTimeInterval(-86_400), label: "Microblading"
        )
        let plan = SessionPlan(id: UUID(), clientID: client.id, name: "Skin barrier repair", totalSessions: 6,
                               intervalWeeks: 4, startDate: clock.now, remindToRebook: true)
        try await repository.save(consent)
        try await repository.save(unsigned)
        try await repository.save(plan)

        #expect(try await repository.consents(for: client.id) == [consent, unsigned], "the most recent first")
        #expect(try await repository.sessionPlans(for: client.id) == [plan])

        try await repository.deleteConsent(id: consent.id)
        try await repository.deleteConsent(id: UUID())
        #expect(try await repository.consents(for: client.id) == [unsigned])
    }
}
