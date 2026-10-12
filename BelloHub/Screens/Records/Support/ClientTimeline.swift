//
//  ClientTimeline.swift
//  BelloHub
//

import Foundation

/// A client's history as the record's "History" section shows it.
struct ClientTimeline: Equatable, Sendable {
    /// Newest first.
    let entries: [ClientTimelineEntry]
    /// The newest visit with a record (draft or finalized), shown on top as "Last visit".
    let lastVisit: VisitSummary?
    /// Photos tied to no record (or to one that no longer exists): kept, shown apart, and offered for organizing.
    let unlinkedPhotos: [Photo]

    static let empty = ClientTimeline(entries: [], lastVisit: nil, unlinkedPhotos: [])

    var visits: [VisitSummary] {
        entries.compactMap { entry -> VisitSummary? in
            guard case .visit(let visit) = entry else { return nil }
            return visit
        }
    }

    var pendingRecords: [Appointment] {
        entries.compactMap { entry -> Appointment? in
            guard case .pendingRecord(let appointment) = entry else { return nil }
            return appointment
        }
    }

    var drafts: [VisitSummary] { visits.filter { $0.state == .draft } }
}
