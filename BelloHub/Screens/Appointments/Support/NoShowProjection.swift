//
//  NoShowProjection.swift
//  BelloHub
//

import Foundation

/// What marking this visit would do to the client's count (3.7): the count now, the count after, and whether the limit
/// is reached. The rule itself belongs to `NoShowEvaluator`; this only adds "this one" to it.
struct NoShowProjection: Equatable, Sendable {
    let before: NoShowStatus
    /// The status if this visit is stored as a no-show that counts.
    let after: NoShowStatus
    let action: NoShowAction

    /// Counting this one is what makes her reach the limit.
    var reachesLimit: Bool {
        after.limitReached && !before.limitReached
    }

    /// What the projection reads: the rule, the client, her visits, and the visit being marked.
    struct Input: Sendable {
        let policy: NoShowPolicy
        let client: Client
        let appointments: [Appointment]
        let marking: Appointment
    }

    static func make(_ input: Input, now: Date, calendar: Calendar) -> NoShowProjection {
        var counted = input.marking
        counted.status = .noShow
        counted.noShowForgiven = false
        let others = input.appointments.filter { $0.id != input.marking.id }
        let before = NoShowEvaluator.status(
            policy: input.policy, client: input.client, appointments: others + [input.marking], now: now,
            calendar: calendar
        )
        let after = NoShowEvaluator.status(
            policy: input.policy, client: input.client, appointments: others + [counted], now: now, calendar: calendar
        )
        return NoShowProjection(before: before, after: after, action: input.policy.action)
    }
}
