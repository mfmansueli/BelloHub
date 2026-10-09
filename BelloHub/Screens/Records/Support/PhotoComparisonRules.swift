//
//  PhotoComparisonRules.swift
//  BelloHub
//

import Foundation

/// Which photos of a client belong together and in what order 4.7 shows them.
enum PhotoComparisonRules {
    /// One pair per visit that has both a "before" and an "after" (the latest of each), newest visit first. Photos with
    /// no visit are grouped together as one visit of their own.
    static func pairs(_ photos: [Photo]) -> [BeforeAfterPair] {
        let visits = Dictionary(grouping: photos, by: \.recordID)
        return visits.values
            .compactMap { group -> BeforeAfterPair? in
                guard let before = latest(.before, in: group), let after = latest(.after, in: group) else { return nil }
                return BeforeAfterPair(before: before, after: after)
            }
            .sorted { $0.after.takenAt > $1.after.takenAt }
    }

    /// Every photo, newest first, for the timeline.
    static func timeline(_ photos: [Photo]) -> [Photo] {
        photos.sorted { $0.takenAt == $1.takenAt ? $0.id.uuidString < $1.id.uuidString : $0.takenAt > $1.takenAt }
    }

    /// The visibilities she may pick for a photo. Without a signed photo consent only "Only me" is offered, and a photo
    /// already shared keeps its value in the list so the picker never shows a value it cannot represent.
    static func visibilityOptions(for photo: Photo, hasConsent: Bool) -> [PhotoVisibility] {
        var options = PhotoConsentRules.allowedVisibilities(hasConsent: hasConsent)
        if !options.contains(photo.visibility) { options.append(photo.visibility) }
        return options
    }

    private static func latest(_ kind: PhotoKind, in photos: [Photo]) -> Photo? {
        photos.filter { $0.kind == kind }.max { $0.takenAt < $1.takenAt }
    }
}
