//
//  HealthReviewStatus.swift
//  BelloHub
//

import Foundation

/// Where a client's health form stands against the professional's "ask again every N months".
enum HealthReviewStatus: Hashable, Sendable {
    /// The form has no signature date, so there is nothing to count from.
    case undated
    /// Still within the period; the review is due on `dueAt`.
    case current(dueAt: Date)
    /// The period has passed (or ends right now): ask her to confirm or update her answers.
    case due(dueAt: Date)

    var isDue: Bool {
        if case .due = self { return true }
        return false
    }
}
