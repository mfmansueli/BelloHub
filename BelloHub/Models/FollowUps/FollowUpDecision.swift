//
//  FollowUpDecision.swift
//  BelloHub
//

import Foundation

/// What she decided about one suggestion of the queue, kept on this iPhone (`FollowUpQueueStore`): snoozed until a
/// day, dismissed, or marked as sent by her. Keyed by the suggestion's occurrence, so a new visit (a new occurrence)
/// brings the client back when it is due again.
struct FollowUpDecision: Equatable, Codable, Sendable {
    var snoozedUntil: Date?
    var dismissedAt: Date?
    var markedSentAt: Date?

    /// How long a suggestion stays aside after she marked the message as sent.
    static let afterSentDays = 14
    /// How long "Later" puts a suggestion aside.
    static let snoozeDays = 7

    /// Whether the suggestion is out of the active list at `now`.
    func setsAside(at now: Date) -> Bool {
        if dismissedAt != nil { return true }
        if let snoozedUntil { return snoozedUntil > now }
        return false
    }
}
