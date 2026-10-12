//
//  ClientProfileSnapshot.swift
//  BelloHub
//

import Foundation

/// A client's profile as the screen shows it, computed once per change of the vault.
struct ClientProfileSnapshot: Equatable, Sendable {
    /// A series of sessions that is not finished, with where she is in it.
    struct ActivePlan: Equatable, Sendable {
        let plan: SessionPlan
        let progress: SessionPlanProgress
    }

    let client: Client
    let habits: ClientHabits
    let lastVisit: Appointment?
    let nextAppointment: Appointment?
    let plan: ActivePlan?
    let health: ClientHealthSummary
    /// Her consent notes and health forms, newest first, for the record's "Documents" section.
    var consents: [ConsentRecord] = []
    var forms: [HealthForm] = []
}
