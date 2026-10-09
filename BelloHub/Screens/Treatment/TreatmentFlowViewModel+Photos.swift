//
//  TreatmentFlowViewModel+Photos.swift
//  BelloHub
//

import Foundation

/// Photos added in the flow (5.7 and 5.8). Every photo is processed by `PhotoProcessing` (size, no metadata, thumbnail)
/// and saved at once through the vault, tied to this client and this record; nothing goes to the photo library.
extension TreatmentFlowViewModel {
    var allowedVisibilities: [PhotoVisibility] {
        PhotoConsentRules.allowedVisibilities(hasConsent: hasPhotoConsent)
    }

    /// The latest before and after, for the side-by-side preview.
    var pair: (before: FlowPhoto?, after: FlowPhoto?) {
        let found = PhotoConsentRules.pair(photos.map(\.photo))
        return (photos.first { $0.id == found.before?.id }, photos.first { $0.id == found.after?.id })
    }

    /// Prepares and saves one photo. Returns whether it worked; on failure `failure` is `.photo` and nothing was saved.
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
            let photo = Photo(
                id: makeID(), clientID: clientID, recordID: savedRecord?.id, takenAt: now(), kind: kind,
                visibility: PhotoConsentRules.visibility(requested: visibility, hasConsent: hasPhotoConsent)
            )
            try await repository.save(photo, data: data)
            photos.append(FlowPhoto(photo: photo, data: data))
            return true
        } catch {
            failure = .photo
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

    func deletePhoto(_ id: UUID) async {
        guard let repository else { return }
        do {
            try await repository.deletePhoto(id: id)
            photos.removeAll { $0.id == id }
        } catch {
            failure = .photo
        }
    }

    /// An earlier photo to lay over the camera as a ghost, so the new one lines up with it: the latest of the other kind.
    func ghostThumbnail(for kind: PhotoKind) -> Data? {
        let other: PhotoKind = kind == .before ? .after : .before
        return photos.last { $0.photo.kind == other }?.data.thumbnail
    }
}
