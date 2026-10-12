//
//  RecordRoute.swift
//  BelloHub
//

import Foundation

/// A client's record screens, pushed from the client profile (and from anywhere that shows one). A stack adds
/// `.recordDestinations()` at its root.
enum RecordRoute: Hashable, Sendable {
    /// 4.7 RecordHistory.
    case history(clientID: UUID)
    /// One visit's full details: everything its record says, its photos, incidents, documents and change history.
    case visit(recordID: UUID)
}

/// The record's sheets.
enum RecordSheet: Hashable, Identifiable, Sendable {
    /// 4.9 Incident, optionally tied to the visit it happened in (by its record, or by the appointment's record).
    case incident(clientID: UUID, appointmentID: UUID?, recordID: UUID? = nil)
    /// 4.10 ExportRecord.
    case exportRecord(clientID: UUID)
    /// Photos that belong to no visit, to place each one in the visit it came from.
    case organizePhotos(clientID: UUID)

    var id: Self { self }
}
