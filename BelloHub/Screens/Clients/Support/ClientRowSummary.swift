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
    /// next slot does. A client who has never been seen shows what is booked, if anything.
    static func make(appointments: [Appointment], now: Date) -> ClientRowSummary {
        if let last = appointments.filter({ $0.status == .completed }).max(by: { $0.startsAt < $1.startsAt }) {
            return .lastVisit(service: last.serviceName, date: last.startsAt)
        }
        let upcoming = appointments.filter { $0.status.holdsTime && $0.startsAt >= now }
        if let next = upcoming.min(by: { $0.startsAt < $1.startsAt }) {
            return .booked(service: next.serviceName, date: next.startsAt)
        }
        return .noVisitsYet
    }
}
