//
//  SessionPlanRules.swift
//  BelloHub
//

import Foundation

/// The rules of the plan form (4.8): the allowed sizes, whether it can be saved, which plan the screen opens on and
/// the timeline a draft would produce. Pure.
enum SessionPlanRules {
    static let sessionRange = 2...24
    static let intervalWeekRange = 1...12
    static let maxNameLength = 60

    static func canSave(_ draft: SessionPlanDraft) -> Bool {
        let name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return !name.isEmpty && name.count <= maxNameLength && sessionRange.contains(draft.totalSessions)
            && intervalWeekRange.contains(draft.intervalWeeks)
    }

    /// The plan the screen opens on: the one in progress, otherwise the latest one (finished), otherwise nothing, and
    /// the form starts a new plan.
    static func openingPlan(plans: [SessionPlan], appointments: [Appointment], calendar: Calendar) -> SessionPlan? {
        let newestFirst = plans.sorted { $0.startDate > $1.startDate }
        return newestFirst.first {
            !SessionPlanProgress.make(plan: $0, appointments: appointments, calendar: calendar).isFinished
        } ?? newestFirst.first
    }

    /// The plan to store: `existing` with the draft's values, or a new one that starts at `now`.
    static func plan(
        from draft: SessionPlanDraft, clientID: UUID, existing: SessionPlan?, now: Date, id: UUID = UUID()
    ) -> SessionPlan {
        var plan = existing ?? SessionPlan(
            id: id, clientID: clientID, name: "", totalSessions: draft.totalSessions,
            intervalWeeks: draft.intervalWeeks, startDate: now, remindToRebook: draft.remindToRebook
        )
        plan.name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        plan.totalSessions = draft.totalSessions
        plan.intervalWeeks = draft.intervalWeeks
        plan.remindToRebook = draft.remindToRebook
        return plan
    }

    /// The steps the draft would give, drawn from the client's completed visits, so changing a number moves the dates
    /// at once.
    static func timeline(
        for draft: SessionPlanDraft, existing: SessionPlan?, appointments: [Appointment], now: Date,
        calendar: Calendar
    ) -> SessionPlanProgress {
        // The client id does not matter here: progress is read from the visits linked to the plan's id.
        let plan = plan(from: draft, clientID: existing?.clientID ?? UUID(), existing: existing, now: now,
                        id: existing?.id ?? UUID())
        return SessionPlanProgress.make(plan: plan, appointments: appointments, calendar: calendar)
    }
}
