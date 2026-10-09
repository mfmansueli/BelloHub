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
}

/// The record's sheets.
enum RecordSheet: Hashable, Identifiable, Sendable {
    /// 4.9 Incident, optionally tied to the visit it happened in.
    case incident(clientID: UUID, appointmentID: UUID?)
    /// 4.10 ExportRecord.
    case exportRecord(clientID: UUID)

    var id: Self { self }
}
