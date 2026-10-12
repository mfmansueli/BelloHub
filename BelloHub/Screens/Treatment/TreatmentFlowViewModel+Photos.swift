//
//  TreatmentFlowViewModel+Photos.swift
//  BelloHub
//

import Foundation

/// Photos of the visit, taken or imported at any moment: before the form is filled, in the middle, or after it is
/// finalized. Every photo is processed by `PhotoProcessing` (size, no metadata, thumbnail) and saved at once through
/// the vault, tied to this client and this record by its id; nothing goes to the photo library. The draft is stored
/// first when it does not exist yet, so a photo never points to a record that is not there.
extension TreatmentFlowViewModel {
    var allowedVisibilities: [PhotoVisibility] {
        PhotoConsentRules.allowedVisibilities(hasConsent: hasPhotoConsent)
    }

    /// The latest before and after, for the side-by-side preview.
    var pair: (before: FlowPhoto?, after: FlowPhoto?) {
        let found = PhotoConsentRules.pair(photos.map(\.photo))
        return (photos.first { $0.id == found.before?.id }, photos.first { $0.id == found.after?.id })
    }

    /// The kind the camera or the library proposes next: before, then after, then progress.
    var nextPhotoKind: PhotoKind {
        if pair.before == nil { return .before }
        if pair.after == nil { return .after }
        return .progress
    }

    /// Prepares and saves one photo. Returns whether it worked; on failure `failure` is `.photo` (or `.save` when the
    /// draft could not be stored) and no photo was saved.
    @discardableResult
    func addPhoto(
        _ source: Data, kind: PhotoKind, visibility: PhotoVisibility = .professionalOnly
    ) async -> Bool {
        guard let repository else { return false }
        isProcessingPhoto = true
        failure = nil
        defer { isProcessingPhoto = false }
        do {
            let data = try await photoProcessing.process(source)
            guard await ensureStored() else { return false }
            let photo = Photo(
                id: makeID(), clientID: clientID, recordID: recordID, takenAt: now(), kind: kind,
                visibility: PhotoConsentRules.visibility(requested: visibility, hasConsent: hasPhotoConsent)
            )
            try await repository.save(photo, data: data)
            photos.append(FlowPhoto(photo: photo, data: data))
            if case .idle = autosave { autosave = .saved(now()) }
            return true
        } catch {
            failure = .photo
            await removeIfEmpty()
            return false
        }
    }

    func setVisibility(_ visibility: PhotoVisibility, for id: UUID) async {
        guard let repository, let index = photos.firstIndex(where: { $0.id == id }) else { return }
        var changed = photos[index]
        changed.photo.visibility = PhotoConsentRules.visibility(requested: visibility, hasConsent: hasPhotoConsent)
        do {
            try await repository.save(changed.photo, data: changed.data)
            photos[index] = changed
        } catch {
            failure = .photo
        }
    }

    func setKind(_ kind: PhotoKind, for id: UUID) async {
        guard let repository, let index = photos.firstIndex(where: { $0.id == id }) else { return }
        var changed = photos[index]
        changed.photo.kind = kind
        do {
            try await repository.save(changed.photo, data: changed.data)
            photos[index] = changed
        } catch {
            failure = .photo
        }
    }

    /// Removes a photo of a visit still open. A locked record keeps its photos: what it showed stays as it was.
    func deletePhoto(_ id: UUID) async {
        guard let repository, !isLocked else { return }
        do {
            try await repository.deletePhoto(id: id)
            photos.removeAll { $0.id == id }
            await removeIfEmpty()
        } catch {
            failure = .photo
        }
    }

    /// A draft stored only to hold a photo leaves no trace once that photo is gone (it failed to save, or she removed
    /// it) and nothing else was written.
    private func removeIfEmpty() async {
        guard let repository, !hasContent, savedRecord?.isDraft == true else { return }
        guard (try? await repository.deleteDraft(id: recordID)) != nil else { return }
        savedRecord = nil
        autosave = .idle
    }
}
