//
//  PhotoGroup.swift
//  BelloHub
//

import Foundation

/// The photos of one visit (or the ones that belong to no visit), for the record's "Photos" section.
struct PhotoGroup: Identifiable, Equatable, Sendable {
    /// Nil for the photos that belong to no visit.
    let visit: VisitSummary?
    let photos: [Photo]

    var id: String { visit.map { $0.id.uuidString } ?? "unlinked" }

    /// Groups the timeline's photos by visit, newest visit first, keeping only `kind` when one is chosen. The photos
    /// with no visit come last. A group left empty by the filter is dropped.
    static func groups(from timeline: ClientTimeline, kind: PhotoKind?) -> [PhotoGroup] {
        func matching(_ photos: [Photo]) -> [Photo] {
            kind.map { wanted in photos.filter { $0.kind == wanted } } ?? photos
        }
        var groups = timeline.visits.map { PhotoGroup(visit: $0, photos: matching($0.photos)) }
        groups.append(PhotoGroup(visit: nil, photos: matching(timeline.unlinkedPhotos.reversed())))
        return groups.filter { !$0.photos.isEmpty }
    }
}
