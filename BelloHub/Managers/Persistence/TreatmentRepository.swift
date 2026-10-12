//
//  TreatmentRepository.swift
//  BelloHub
//

import Foundation

/// Treatment records with their 24-hour lock, corrections, incidents and photos.
protocol TreatmentRepository: Sendable {
    func records(for clientID: UUID) async throws -> [TreatmentRecord]
    func record(id: UUID) async throws -> TreatmentRecord?
    /// Inserts a record, or edits an existing one **while it is not locked**. A locked record throws
    /// `VaultRepositoryError.recordLocked`: use `addCorrection` (D9, `RecordLockPolicy`).
    func save(_ record: TreatmentRecord) async throws
    /// Adds a logged correction to a locked record. Corrections are never edited or deleted. Adding the same
    /// correction id twice is a no-op.
    /// Deletes a draft she does not want, with the photos tied to it. A finalized record is never deleted this way
    /// (`recordLocked`): it changes only by corrections, and goes only with the client's data.
    func deleteDraft(id: UUID) async throws
    func addCorrection(_ correction: RecordCorrection) async throws
    func corrections(for recordID: UUID) async throws -> [RecordCorrection]

    func incidents(for clientID: UUID) async throws -> [Incident]
    /// Same lock as a record: an incident past `lockedAt` throws `recordLocked`.
    func save(_ incident: Incident) async throws

    func photos(for clientID: UUID) async throws -> [Photo]
    /// The photo's bytes are encrypted before they reach the store.
    func save(_ photo: Photo, data: PhotoData) async throws
    func photoData(id: UUID) async throws -> PhotoData
    /// Only the thumbnail, decrypted on its own, for strips and timelines that never need the full image.
    func photoThumbnail(id: UUID) async throws -> Data
    func deletePhoto(id: UUID) async throws
}

extension TreatmentRepository {
    func photoThumbnail(id: UUID) async throws -> Data {
        try await photoData(id: id).thumbnail
    }
}
