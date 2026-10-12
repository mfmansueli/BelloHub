//
//  ConsentRecordViewModel.swift
//  BelloHub
//

import Foundation
import Observation
import UniformTypeIdentifiers

/// The consent sheet (D55): a new record, or an existing one being edited. The kind, a label in her words, signed or
/// not, the date, a note and an optional photo or file of the real signed paper. A photo goes through the photo
/// pipeline (resized, no metadata); a file is read once and kept as bytes. Everything is sealed in the vault when she
/// saves; nothing reaches a log, the network or the photo library.
@MainActor
@Observable
final class ConsentRecordViewModel: Identifiable {
    let id = UUID()
    var draft: ConsentRecordDraft
    private(set) var isSaving = false
    private(set) var isPreparingDocument = false
    private(set) var errorMessage: String?
    private(set) var didSave = false
    /// She asked to delete: the sheet shows the confirmation.
    var isConfirmingDelete = false

    /// The record being edited, nil for a new one.
    let existing: ConsentRecord?
    /// The client's visits, newest first, offered as the visit this document belongs to. Linking is optional: a
    /// document can stand on its own, and a visit's record never depends on a document.
    let visits: [TreatmentRecord]
    private let clientID: UUID
    private let repository: any HealthRepository
    private let photos: any PhotoProcessing
    private let files: any ConsentDocumentReading
    private let now: @Sendable () -> Date
    /// Made once, so saving again after a failure updates the same record instead of adding a second one.
    private let recordID: UUID

    init(
        clientID: UUID,
        existing: ConsentRecord? = nil,
        repository: any HealthRepository,
        visits: [TreatmentRecord] = [],
        photos: any PhotoProcessing = ImageIOPhotoProcessing(),
        files: any ConsentDocumentReading = SystemConsentDocumentReader(),
        now: @escaping @Sendable () -> Date = { Date() },
        makeID: @Sendable () -> UUID = { UUID() }
    ) {
        self.clientID = clientID
        self.existing = existing
        self.repository = repository
        self.visits = visits
        self.photos = photos
        self.files = files
        self.now = now
        self.recordID = existing?.id ?? makeID()
        self.draft = existing.map { ConsentRecordRules.draft(from: $0, now: now()) }
            ?? ConsentRecordDraft(signedAt: now())
    }

    // MARK: - What the sheet shows

    var isEditing: Bool { existing != nil }

    var allowedFileTypes: [UTType] { files.allowedContentTypes }

    var canSave: Bool { !isSaving && !isPreparingDocument && ConsentRecordRules.canSave(draft) }

    // MARK: - Document

    /// A picture she took or picked: prepared like a treatment photo (never more than 2048 px, no metadata).
    func attachPhoto(_ source: Data) async {
        guard !isPreparingDocument else { return }
        isPreparingDocument = true
        errorMessage = nil
        defer { isPreparingDocument = false }
        do {
            let prepared = try await photos.process(source)
            draft.document = ConsentDocument(
                kind: .photo, fileName: nil, contentType: UTType.jpeg.identifier, data: prepared.image,
                thumbnail: prepared.thumbnail
            )
        } catch {
            errorMessage = String(interface: LocalizedStringResource("consent.document.error"))
        }
    }

    /// The file importer's result. A picture chosen as a file is prepared as a photo; a PDF is kept as it is.
    func attachFile(_ outcome: Result<URL, any Error>) async {
        guard !isPreparingDocument else { return }
        guard case .success(let url) = outcome else { return }
        isPreparingDocument = true
        errorMessage = nil
        defer { isPreparingDocument = false }
        do {
            let file = try await files.readFile(at: url)
            if file.contentType.conforms(to: .image) {
                let prepared = try await photos.process(file.data)
                draft.document = ConsentDocument(
                    kind: .photo, fileName: file.fileName, contentType: UTType.jpeg.identifier,
                    data: prepared.image, thumbnail: prepared.thumbnail
                )
            } else {
                guard ConsentRecordRules.acceptsDocument(bytes: file.data.count) else {
                    throw ConsentDocumentError.tooLarge
                }
                draft.document = ConsentDocument(
                    kind: .file, fileName: file.fileName, contentType: file.contentType.identifier,
                    data: file.data, thumbnail: nil
                )
            }
        } catch ConsentDocumentError.tooLarge {
            errorMessage = String(interface: LocalizedStringResource("consent.document.tooLarge"))
        } catch {
            errorMessage = String(interface: LocalizedStringResource("consent.document.error"))
        }
    }

    func removeDocument() {
        draft.document = nil
    }

    // MARK: - Saving

    /// Fire-and-forget entry point for the button; `saveAsync()` is what tests await.
    func save() {
        Task { await saveAsync() }
    }

    func saveAsync() async {
        guard canSave else { return }
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        let record = ConsentRecordRules.record(
            from: draft, clientID: clientID, id: recordID, createdAt: existing?.createdAt ?? now(), now: now()
        )
        do {
            try await repository.save(record)
            didSave = true
        } catch {
            errorMessage = String(interface: LocalizedStringResource("health.error.save"))
        }
    }

    // MARK: - Deleting

    func delete() {
        Task { await deleteAsync() }
    }

    /// Removes the record being edited. A new record has nothing to delete.
    func deleteAsync() async {
        guard let existing, !isSaving else { return }
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        do {
            try await repository.deleteConsent(id: existing.id)
            didSave = true
        } catch {
            errorMessage = String(interface: LocalizedStringResource("health.error.save"))
        }
    }
}
