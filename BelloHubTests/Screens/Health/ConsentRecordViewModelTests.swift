//
//  ConsentRecordViewModelTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@MainActor
@Suite("ConsentRecordViewModel")
struct ConsentRecordViewModelTests {
    private struct Rig {
        let model: ConsentRecordViewModel
        let repository: FlakyHealthRepository
        let clientID: UUID
    }

    private func makeRig(
        existing: ConsentRecord? = nil,
        photos: FakePhotoProcessing = FakePhotoProcessing(),
        files: FakeConsentDocumentReader = FakeConsentDocumentReader(
            files: ["scan.pdf": FakeConsentDocumentReader.pdf(), "paper.jpg": FakeConsentDocumentReader.image()]
        )
    ) async throws -> Rig {
        let repository = FlakyHealthRepository()
        let client = Client(name: "Ana Costa", createdAt: TestClock.days(-100))
        try await repository.save(client)
        // The record belongs to this rig's client, whatever client the factory gave it.
        let existing = existing.map { record in
            var owned = record
            owned.clientID = client.id
            return owned
        }
        if let existing { try await repository.save(existing) }
        let model = ConsentRecordViewModel(
            clientID: client.id, existing: existing, repository: repository, photos: photos, files: files,
            now: { TestClock.now }, makeID: { UUID() }
        )
        return Rig(model: model, repository: repository, clientID: client.id)
    }

    // MARK: - New record

    @Test("A new record starts signed, dated today, as a treatment consent, and can be saved as it is")
    func newRecord() async throws {
        let rig = try await makeRig()
        #expect(!rig.model.isEditing && rig.model.draft.isSigned && rig.model.draft.signedAt == TestClock.now)
        #expect(rig.model.draft.kind == .treatment && rig.model.canSave)

        rig.model.draft.kind = .photos
        rig.model.draft.label = "Photos, paper form"
        rig.model.draft.note = "Signed at the front desk"
        await rig.model.saveAsync()

        #expect(rig.model.didSave && rig.model.errorMessage == nil && !rig.model.isSaving)
        let stored = try #require(try await rig.repository.consents(for: rig.clientID).first)
        #expect(stored.kind == .photos && stored.isSigned && stored.signedAt == TestClock.now)
        #expect(stored.label == "Photos, paper form" && stored.note == "Signed at the front desk")
        #expect(stored.createdAt == TestClock.now && stored.document == nil)
    }

    @Test("A label of one character blocks Save")
    func shortLabel() async throws {
        let rig = try await makeRig()
        rig.model.draft.label = "A"
        #expect(!rig.model.canSave)
        await rig.model.saveAsync()
        #expect(!rig.model.didSave)
    }

    @Test("A failed save says so, and the retry updates the same record instead of adding one")
    func retry() async throws {
        let rig = try await makeRig()
        await rig.repository.fail(.consent)

        await rig.model.saveAsync()
        #expect(!rig.model.didSave && rig.model.errorMessage != nil)

        await rig.repository.fail([])
        await rig.model.saveAsync()
        #expect(rig.model.didSave)
        #expect(try await rig.repository.consents(for: rig.clientID).count == 1)
    }

    // MARK: - Documents

    @Test("A photo goes through the pipeline and is kept with its thumbnail")
    func attachPhoto() async throws {
        let rig = try await makeRig()

        await rig.model.attachPhoto(Data([9, 9, 9]))

        let document = try #require(rig.model.draft.document)
        #expect(document.kind == .photo && document.data == Data([9, 9, 9]) && document.thumbnail == Data([9, 9, 9]))
        #expect(document.contentType == "public.jpeg" && document.fileName == nil)
        #expect(!rig.model.isPreparingDocument && rig.model.errorMessage == nil)

        rig.model.removeDocument()
        #expect(rig.model.draft.document == nil)
    }

    @Test("A photo the pipeline cannot read is refused with a message, and nothing is kept")
    func unreadablePhoto() async throws {
        let rig = try await makeRig(photos: FakePhotoProcessing(fails: true))
        await rig.model.attachPhoto(Data([1]))
        #expect(rig.model.draft.document == nil && rig.model.errorMessage != nil)
    }

    @Test("A PDF is kept as a file with its name; a picture chosen as a file becomes a photo")
    func attachFile() async throws {
        let rig = try await makeRig()

        await rig.model.attachFile(.success(URL(fileURLWithPath: "/tmp/scan.pdf")))
        let pdf = try #require(rig.model.draft.document)
        #expect(pdf.kind == .file && pdf.fileName == "scan.pdf" && pdf.contentType == "com.adobe.pdf")
        #expect(pdf.data.count == 1_024 && pdf.thumbnail == nil)

        await rig.model.attachFile(.success(URL(fileURLWithPath: "/tmp/paper.jpg")))
        let photo = try #require(rig.model.draft.document)
        #expect(photo.kind == .photo && photo.fileName == "paper.jpg" && photo.thumbnail != nil)

        await rig.model.saveAsync()
        #expect(try await rig.repository.consents(for: rig.clientID).first?.document == photo)
    }

    @Test("A file that is too large, unreadable or cancelled leaves the draft as it was")
    func fileProblems() async throws {
        let tooLarge = try await makeRig(files: FakeConsentDocumentReader(failure: .tooLarge))
        await tooLarge.model.attachFile(.success(URL(fileURLWithPath: "/tmp/scan.pdf")))
        #expect(tooLarge.model.draft.document == nil && tooLarge.model.errorMessage != nil)

        let unreadable = try await makeRig(files: FakeConsentDocumentReader())
        await unreadable.model.attachFile(.success(URL(fileURLWithPath: "/tmp/missing.pdf")))
        #expect(unreadable.model.draft.document == nil && unreadable.model.errorMessage != nil)

        let cancelled = try await makeRig()
        await cancelled.model.attachFile(.failure(CocoaError(.userCancelled)))
        #expect(cancelled.model.draft.document == nil && cancelled.model.errorMessage == nil)
    }

    @Test("A file above the cap is refused even when the reader let it through")
    func oversizedFile() async throws {
        let huge = FakeConsentDocumentReader.pdf(named: "huge.pdf", bytes: ConsentDocument.maximumBytes + 1)
        let rig = try await makeRig(files: FakeConsentDocumentReader(files: ["huge.pdf": huge]))
        await rig.model.attachFile(.success(URL(fileURLWithPath: "/tmp/huge.pdf")))
        #expect(rig.model.draft.document == nil && rig.model.errorMessage != nil)
    }

    // MARK: - Editing and deleting

    @Test("Editing starts from the record, keeps its id and day, and can delete it after a confirmation")
    func editAndDelete() async throws {
        let existing = makeConsentRecord(kind: .guardian, daysAgo: 7, label: "Rita, paper")
        let rig = try await makeRig(existing: existing)
        #expect(rig.model.isEditing && rig.model.draft.label == "Rita, paper" && rig.model.draft.kind == .guardian)

        rig.model.draft.isSigned = false
        await rig.model.saveAsync()
        let stored = try #require(try await rig.repository.consents(for: rig.clientID).first)
        #expect(stored.id == existing.id && !stored.isSigned && stored.signedAt == nil)
        #expect(stored.createdAt == existing.createdAt)

        await rig.model.deleteAsync()
        #expect(rig.model.didSave)
        #expect(try await rig.repository.consents(for: rig.clientID).isEmpty)
    }

    @Test("A new record has nothing to delete, and a failed delete says so")
    func deleteGuards() async throws {
        let fresh = try await makeRig()
        await fresh.model.deleteAsync()
        #expect(!fresh.model.didSave && fresh.model.errorMessage == nil)

        let rig = try await makeRig(existing: makeConsentRecord())
        await rig.repository.fail(.consent)
        await rig.model.deleteAsync()
        #expect(!rig.model.didSave && rig.model.errorMessage != nil)
        #expect(try await rig.repository.consents(for: rig.clientID).count == 1)
    }
}
