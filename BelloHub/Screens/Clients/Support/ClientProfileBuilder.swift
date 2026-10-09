//
//  ClientProfileBuilder.swift
//  BelloHub
//

import Foundation

/// Builds the profile of one client. The numbers come from their owners: `HabitsCalculator` for the habits and
/// `SessionPlanProgress` for the plan; this only picks which appointment is "last" and "next".
enum ClientProfileBuilder {
    /// What the vault holds about one client.
    struct Input: Sendable {
        let client: Client
        var appointments: [Appointment] = []
        var plans: [SessionPlan] = []
        var forms: [HealthForm] = []
        var consents: [Consent] = []
    }

    static func make(_ input: Input, now: Date, calendar: Calendar) -> ClientProfileSnapshot {
        let client = input.client
        let own = input.appointments.filter { $0.clientID == client.id }
        return ClientProfileSnapshot(
            client: client,
            habits: HabitsCalculator.habits(for: client.id, appointments: own, now: now, calendar: calendar),
            lastVisit: own.filter { $0.status == .completed }.max { $0.startsAt < $1.startsAt },
            nextAppointment: own.filter { $0.status.holdsTime && $0.startsAt >= now }.min { $0.startsAt < $1.startsAt },
            plan: activePlan(plans: input.plans, appointments: own, calendar: calendar),
            health: .make(forms: input.forms, consents: input.consents)
        )
    }

    /// The most recently started plan that still has sessions to go.
    private static func activePlan(plans: [SessionPlan], appointments: [Appointment], calendar: Calendar)
        -> ClientProfileSnapshot.ActivePlan? {
        plans
            .sorted { $0.startDate > $1.startDate }
            .lazy
            .map { ClientProfileSnapshot.ActivePlan(
                plan: $0, progress: SessionPlanProgress.make(plan: $0, appointments: appointments, calendar: calendar)
            ) }
            .first { !$0.progress.isFinished }
    }
}
