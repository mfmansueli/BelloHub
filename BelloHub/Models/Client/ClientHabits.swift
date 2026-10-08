//
//  ClientHabits.swift
//  BelloHub
//

import Foundation

/// What the professional's own history says about a client's habits. **Derived, never stored, and private to the
/// professional**: the client never sees it. Neutral words: "habits", never "reliability" (D13).
struct ClientHabits: Equatable, Sendable {
    let visits: Int
    /// Cancelled by the client. A cancellation by the professional is never counted.
    let cancelled: Int
    /// Not forgiven.
    let noShows: Int
    let lateCancellations: Int
    /// Share of cancellations and no-shows among the last ten past appointments. Nil before the fourth completed
    /// visit: until then the absolute numbers are shown instead.
    let cancellationRate: Double?
    let cancelsOften: Bool
    let returnsEveryWeeks: Int?
    let usualPeriod: DayPeriod?
    let mostBookedService: String?
    let lastVisit: Date?
    /// Average days between a reminder and the client's confirmation, when she answers them.
    let reminderResponseDays: Double?

    /// The rate is hidden below this many completed visits.
    static let minimumVisitsForRate = 4
    /// "Cancels often" from this rate.
    static let cancelsOftenThreshold = 0.30
    /// The rate looks at this many most recent past appointments.
    static let rateWindow = 10
}
