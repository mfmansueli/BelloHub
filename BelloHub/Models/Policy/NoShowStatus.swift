//
//  NoShowStatus.swift
//  BelloHub
//

/// Where a client stands against the no-show rule.
struct NoShowStatus: Equatable, Sendable {
    /// How many no-shows (and late cancellations, if the policy counts them) count against her now.
    let counted: Int
    let limit: Int
    let isProtectionOn: Bool

    var limitReached: Bool {
        isProtectionOn && counted >= limit
    }

    /// How many more it takes to reach the limit; zero once reached.
    var remainingBeforeLimit: Int {
        max(limit - counted, 0)
    }
}
