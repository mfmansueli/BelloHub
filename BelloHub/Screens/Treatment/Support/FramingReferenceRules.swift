//
//  FramingReferenceRules.swift
//  BelloHub
//

import Foundation

/// Which earlier photo the camera lays over its preview as a framing reference (routine item 11), so a new photo
/// lines up with the one it will be compared with. Pure; the ViewModel loads the bytes in memory only.
///
/// 1. In this visit, the latest photo of the other kind (an "after" lines up with this visit's "before"): the
///    comparison the before/after preview makes.
/// 2. Otherwise, the latest photo of the same kind from an earlier visit (this "before" lines up with the last
///    "before"), so progress photos across visits match.
/// 3. Otherwise, her latest earlier photo of any kind. With no photo at all there is no reference.
enum FramingReferenceRules {
    static func reference(for kind: PhotoKind, thisVisit: [Photo], earlier: [Photo]) -> Photo? {
        let other: PhotoKind = kind == .before ? .after : .before
        if let paired = latest(thisVisit.filter { $0.kind == other }) { return paired }
        let thisVisitIDs = Set(thisVisit.map(\.id))
        let past = earlier.filter { !thisVisitIDs.contains($0.id) }
        return latest(past.filter { $0.kind == kind }) ?? latest(past)
    }

    private static func latest(_ photos: [Photo]) -> Photo? {
        photos.max { $0.takenAt < $1.takenAt }
    }
}
