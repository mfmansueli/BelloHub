//
//  TreatmentFlowViewModel+FramingReference.swift
//  BelloHub
//

import Foundation

/// The framing reference of the camera (routine item 11): an earlier photo of this client, laid over the live preview
/// so the new one lines up with it. The choice is `FramingReferenceRules`; the bytes are decrypted from the vault into
/// memory only, handed to the screen and never written anywhere, composited or sent. The professional already sees
/// these photos in the client's record, so showing one to her on her own camera adds no audience.
extension TreatmentFlowViewModel {
    /// The reference image for a new photo of `kind`, or nil when this client has no photo yet (or the vault cannot
    /// be read: the camera then works as before, without a reference).
    func framingReference(for kind: PhotoKind) async -> Data? {
        let thisVisit = photos.map(\.photo)
        let earlier = (try? await repository?.photos(for: clientID)) ?? []
        guard let chosen = FramingReferenceRules.reference(for: kind, thisVisit: thisVisit, earlier: earlier) else {
            return nil
        }
        if let local = photos.first(where: { $0.id == chosen.id }) { return local.data.image }
        return try? await repository?.photoData(id: chosen.id).image
    }
}
