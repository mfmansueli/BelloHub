//
//  VisitClosing.swift
//  BelloHub
//

import Foundation

/// How far she got in closing one visit after the record was saved (routine-a item 7): Register, then the optional
/// photos, aftercare and return steps. Kept on this iPhone per user (`VisitClosingStore`), outside the record itself,
/// so the record's lock and correction history are untouched; it holds ids and flags only, nothing clinical. While a
/// step is open and she chose "Finish later", the follow-up queue lists the visit as unfinished.
struct VisitClosing: Identifiable, Equatable, Codable, Sendable {
    enum Step: String, CaseIterable, Codable, Sendable {
        case photos
        case aftercare
        case nextVisit
    }

    /// The record's id: one closing per record, so resuming never makes a second record.
    let id: UUID
    let clientID: UUID
    var appointmentID: UUID?
    var serviceName: String
    var recordCreatedAt: Date
    /// Steps she finished or skipped.
    var settled: Set<Step> = []
    /// She left with "Finish later": the queue shows the visit until every step is settled.
    var isDeferred = false

    var openSteps: [Step] {
        Step.allCases.filter { !settled.contains($0) }
    }

    var isComplete: Bool { openSteps.isEmpty }

    /// The first step still open, where a resumed flow starts.
    var nextStep: Step? { openSteps.first }
}
