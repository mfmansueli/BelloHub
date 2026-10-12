//
//  SwiftDataClientRecordRepository+Treatment.swift
//  BelloHub
//

import Foundation

extension SwiftDataClientRecordRepository {
    func recordMarks() throws -> [RecordMark] {
        try values(TreatmentRecord.self, from: items(kind: .treatmentRecord)).map(RecordMark.init)
    }

    func records(for clientID: UUID) throws -> [TreatmentRecord] {
        try values(TreatmentRecord.self, from: items(kind: .treatmentRecord, ownerID: clientID))
            .sorted { $0.createdAt > $1.createdAt }
    }

    func record(id: UUID) throws -> TreatmentRecord? {
        try item(kind: .treatmentRecord, id: id).map { try value(TreatmentRecord.self, from: $0) }
    }

    func save(_ record: TreatmentRecord) throws {
        // The lock and draft rules live in one place for both repositories.
        let stored = try TreatmentRecordSaveRule.stored(record, existing: try self.record(id: record.id), now: clock())
        try upsert(stored)
        try commit()
    }

    func deleteDraft(id: UUID) throws {
        guard let found = try item(kind: .treatmentRecord, id: id) else { return }
        let record = try value(TreatmentRecord.self, from: found)
        guard record.isDraft else { throw VaultRepositoryError.recordLocked }
        let photos = try items(kind: .photo, ownerID: record.clientID).filter { $0.secondaryID == id }
        delete([found] + photos)
        try commit()
    }

    func addCorrection(_ correction: RecordCorrection) throws {
        guard let record = try self.record(id: correction.recordID) else { throw VaultRepositoryError.notFound }
        guard RecordLockPolicy.isLocked(lockedAt: record.lockedAt, now: clock()) else {
            throw VaultRepositoryError.recordNotLocked
        }
        // A correction is never edited: the same id again is a no-op.
        guard try item(kind: .correction, id: correction.id) == nil else { return }
        try upsert(correction)
        try commit()
    }

    func corrections(for recordID: UUID) throws -> [RecordCorrection] {
        try values(RecordCorrection.self, from: items(kind: .correction, ownerID: recordID))
            .sorted { $0.createdAt < $1.createdAt }
    }

    func incidents(for clientID: UUID) throws -> [Incident] {
        try values(Incident.self, from: items(kind: .incident, ownerID: clientID))
            .sorted { $0.occurredAt > $1.occurredAt }
    }

    func save(_ incident: Incident) throws {
        var stored = incident
        if let existing = try item(kind: .incident, id: incident.id).map({ try value(Incident.self, from: $0) }) {
            guard !RecordLockPolicy.isLocked(lockedAt: existing.lockedAt, now: clock()) else {
                throw VaultRepositoryError.recordLocked
            }
            stored.lockedAt = existing.lockedAt
        }
        try upsert(stored)
        try commit()
    }

    func photos(for clientID: UUID) throws -> [Photo] {
        try values(Photo.self, from: items(kind: .photo, ownerID: clientID)).sorted { $0.takenAt < $1.takenAt }
    }

    func save(_ photo: Photo, data: PhotoData) throws {
        try upsert(photo)
        guard let stored = try item(kind: .photo, id: photo.id) else { throw VaultRepositoryError.notFound }
        let model = VaultKind.photo.rawValue
        stored.blob = try codec.sealData(data.image, model: model, id: photo.id, field: "image")
        stored.thumbnail = try codec.sealData(data.thumbnail, model: model, id: photo.id, field: "thumbnail")
        try commit()
    }

    func photoData(id: UUID) throws -> PhotoData {
        guard let stored = try item(kind: .photo, id: id), let blob = stored.blob,
              let thumbnail = stored.thumbnail else {
            throw VaultRepositoryError.notFound
        }
        let model = VaultKind.photo.rawValue
        do {
            return PhotoData(
                image: try codec.openData(blob, model: model, id: id, field: "image"),
                thumbnail: try codec.openData(thumbnail, model: model, id: id, field: "thumbnail")
            )
        } catch let error as VaultError {
            throw error
        } catch {
            throw VaultRepositoryError.unreadable
        }
    }

    /// Decrypts the thumbnail alone: a timeline of 200 photos never opens 200 full images.
    func photoThumbnail(id: UUID) throws -> Data {
        guard let stored = try item(kind: .photo, id: id), let thumbnail = stored.thumbnail else {
            throw VaultRepositoryError.notFound
        }
        do {
            return try codec.openData(thumbnail, model: VaultKind.photo.rawValue, id: id, field: "thumbnail")
        } catch let error as VaultError {
            throw error
        } catch {
            throw VaultRepositoryError.unreadable
        }
    }

    func deletePhoto(id: UUID) throws {
        if let found = try item(kind: .photo, id: id) { delete([found]) }
        try commit()
    }
}
