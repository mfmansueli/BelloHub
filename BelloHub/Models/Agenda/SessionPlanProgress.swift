//
//  SessionPlanProgress.swift
//  BelloHub
//

import Foundation

/// Where a client is in a plan of sessions ("session 3 of 6, every 4 weeks"). Pure.
struct SessionPlanProgress: Equatable, Sendable {
    struct Step: Equatable, Sendable {
        let number: Int
        /// The visit's day when done, the suggested day otherwise.
        let date: Date?
        let state: SessionStepState
    }

    let totalSessions: Int
    let completedSessions: Int
    let steps: [Step]

    var isFinished: Bool {
        completedSessions >= totalSessions
    }

    /// The session she is on, or nil when the plan is finished.
    var currentSessionNumber: Int? {
        isFinished ? nil : completedSessions + 1
    }

    /// When the next session is suggested: the plan's interval after the last completed one, or the plan's start.
    var nextSuggestedDate: Date? {
        steps.first { $0.state == .current }?.date
    }

    static func make(plan: SessionPlan, appointments: [Appointment], calendar: Calendar) -> SessionPlanProgress {
        let done = appointments
            .filter { $0.sessionPlanID == plan.id && $0.status == .completed }
            .sorted { $0.startsAt < $1.startsAt }
            .prefix(plan.totalSessions)
        let completed = done.count
        var steps: [Step] = []
        var previous = plan.startDate
        for number in 1...max(plan.totalSessions, 1) {
            if number <= completed {
                let visit = done[done.startIndex + number - 1].startsAt
                steps.append(Step(number: number, date: visit, state: .done))
                previous = visit
            } else {
                let suggested = number == 1 && completed == 0
                    ? plan.startDate
                    : calendar.date(byAdding: .day, value: plan.intervalWeeks * 7, to: previous)
                let state: SessionStepState = number == completed + 1 ? .current : .upcoming
                steps.append(Step(number: number, date: suggested, state: state))
                previous = suggested ?? previous
            }
        }
        return SessionPlanProgress(totalSessions: plan.totalSessions, completedSessions: completed, steps: steps)
    }
}
