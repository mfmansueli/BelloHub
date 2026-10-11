//
//  PhotoConsentRules.swift
//  BelloHub
//

import Foundation

/// Who may see a photo, given what the client agreed to (D2): private to the professional always; shown to the client
/// or in a portfolio only when a signed photo consent exists. A photo never becomes more public than the consent says.
enum PhotoConsentRules {
    /// The most recent photo consent record she marked signed (D55), or nil. An unsigned record counts for nothing.
    static func latestPhotoConsent(_ consents: [ConsentRecord]) -> ConsentRecord? {
        consents.filter { $0.kind == .photos && $0.isSigned }.max { $0.effectiveDate < $1.effectiveDate }
    }

    static func allowedVisibilities(hasConsent: Bool) -> [PhotoVisibility] {
        hasConsent ? PhotoVisibility.allCases : [.professionalOnly]
    }

    /// The visibility to store for a request: the request when the consent allows it, private otherwise.
    static func visibility(requested: PhotoVisibility, hasConsent: Bool) -> PhotoVisibility {
        allowedVisibilities(hasConsent: hasConsent).contains(requested) ? requested : .professionalOnly
    }

    /// The photos the side-by-side preview shows: the latest "before" and the latest "after".
    static func pair(_ photos: [Photo]) -> (before: Photo?, after: Photo?) {
        func latest(_ kind: PhotoKind) -> Photo? {
            photos.filter { $0.kind == kind }.max { $0.takenAt < $1.takenAt }
        }
        return (latest(.before), latest(.after))
    }
}
