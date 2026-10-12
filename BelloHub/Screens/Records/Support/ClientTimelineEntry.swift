//
//  ClientTimelineEntry.swift
//  BelloHub
//

import Foundation

/// One line of a client's timeline. A treatment that happened is a `visit`; a booking that did not become a treatment
/// (cancelled, no-show) is `notHeld` and never looks like a visit; a completed booking with no record yet is
/// `pendingRecord`, with a way to fill it in.
enum ClientTimelineEntry: Identifiable, Equatable, Sendable {
    case visit(VisitSummary)
    case pendingRecord(Appointment)
    case notHeld(Appointment)
    /// An incident she noted without tying it to a visit.
    case incident(Incident)

    var id: String {
        switch self {
        case .visit(let visit): "visit.\(visit.id.uuidString)"
        case .pendingRecord(let appointment): "pending.\(appointment.id.uuidString)"
        case .notHeld(let appointment): "notHeld.\(appointment.id.uuidString)"
        case .incident(let incident): "incident.\(incident.id.uuidString)"
        }
    }

    var date: Date {
        switch self {
        case .visit(let visit): visit.visitDate.date
        case .pendingRecord(let appointment), .notHeld(let appointment): appointment.startsAt
        case .incident(let incident): incident.occurredAt
        }
    }

    /// Breaks a tie between lines at the same moment: a visit first, then a pending record, then the rest.
    var rank: Int {
        switch self {
        case .visit: 0
        case .pendingRecord: 1
        case .incident: 2
        case .notHeld: 3
        }
    }
}
