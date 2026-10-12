//
//  ClientRowSummary.swift
//  BelloHub
//

import Foundation

/// The second line of a client row: when she was last seen, or what is booked for her, or that nothing happened yet.
/// Pure: the row formats the date and the service name.
enum ClientRowSummary: Equatable, Sendable {
    case lastVisit(service: String, date: Date)
    case booked(service: String, date: Date)
    case noVisitsYet

    /// A completed visit wins over a booking: "Glow Facial, Aug 30" tells her more about a returning client than the
    /// next slot does. A visit recorded with no booking (a walk-in) counts as a visit too. A client who has never been
    /// seen shows what is booked, if anything.
    static func make(appointments: [Appointment], walkIns: [RecordMark] = [], now: Date) -> ClientRowSummary {
        let completed = appointments.filter { $0.status == .completed }.map { ($0.serviceName, $0.startsAt) }
        let recorded = walkIns.filter { $0.isWalkInVisit && $0.visitDate <= now }.map { ($0.serviceName, $0.visitDate) }
        if let last = (completed + recorded).max(by: { $0.1 < $1.1 }) {
            return .lastVisit(service: last.0, date: last.1)
        }
        let upcoming = appointments.filter { $0.status.holdsTime && $0.startsAt >= now }
        if let next = upcoming.min(by: { $0.startsAt < $1.startsAt }) {
            return .booked(service: next.serviceName, date: next.startsAt)
        }
        return .noVisitsYet
    }
}
