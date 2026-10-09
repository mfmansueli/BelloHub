//
//  SessionPlanDraft.swift
//  BelloHub
//

import Foundation

/// What the plan form holds while she edits it (4.8).
struct SessionPlanDraft: Equatable, Sendable {
    var name = ""
    var totalSessions = 6
    var intervalWeeks = 4
    var remindToRebook = true

    init() {}

    init(plan: SessionPlan) {
        name = plan.name
        totalSessions = plan.totalSessions
        intervalWeeks = plan.intervalWeeks
        remindToRebook = plan.remindToRebook
    }
}
