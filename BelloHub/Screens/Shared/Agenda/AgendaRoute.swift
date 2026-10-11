//
//  AgendaRoute.swift
//  BelloHub
//

import Foundation

/// Where an agenda screen can push, shared by the Home, Calendar and Clients stacks so a visit opens the same way
/// from everywhere. Each stack adds `.agendaDestinations()` to its root.
enum AgendaRoute: Hashable, Sendable {
    /// 3.2 Appointment.
    case appointment(id: UUID)
    /// 2.6 WeekGlance.
    case weekGlance
    /// 2.7 The follow-up queue (routine-a item 5), on one of its filters.
    case followUps(FollowUpFilter)
    /// 2.8 Win back: the queue on "Not back".
    case winBack
    /// 4.8 SessionPlan of one client.
    case sessionPlan(clientID: UUID)
    /// 4.11 NoShowHistory of one client.
    case noShowHistory(clientID: UUID)
    /// 2.10 BookingRequest, by the server's booking id.
    case bookingRequest(id: String)
    /// 2.11 RescheduleRequest, by the server's request id.
    case rescheduleRequest(id: String)
    /// 2.9 Waitlist.
    case waitlist
}
