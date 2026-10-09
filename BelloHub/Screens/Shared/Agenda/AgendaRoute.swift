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
    /// 2.7 FollowUps.
    case followUps
    /// 2.8 WinBack.
    case winBack
    /// 4.8 SessionPlan of one client.
    case sessionPlan(clientID: UUID)
    /// 4.11 NoShowHistory of one client.
    case noShowHistory(clientID: UUID)
}
