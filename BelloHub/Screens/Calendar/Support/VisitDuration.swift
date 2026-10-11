//
//  VisitDuration.swift
//  BelloHub
//

import Foundation

/// How long a visit takes: the service, plus its add-ons, plus each guest in sequence with the same service (D19).
/// The same sum as the server's `totalMinutes` in `functions/src/lib/rules.ts`, so a visit booked here and one booked
/// through the link occupy time the same way.
enum VisitDuration {
    /// No visit may take more than this (the server's `MAX_TOTAL_MINUTES`).
    static let maximumMinutes = 12 * 60

    static func totalMinutes(serviceMinutes: Int, addOnMinutes: [Int], guests: Int) -> Int {
        let guests = max(guests, 0)
        return max(serviceMinutes, 0) + addOnMinutes.reduce(0) { $0 + max($1, 0) } + guests * max(serviceMinutes, 0)
    }

    static func exceedsMaximum(_ totalMinutes: Int) -> Bool {
        totalMinutes > maximumMinutes
    }
}
