//
//  TimeBlock.swift
//  BelloHub
//

import Foundation

/// A stretch the professional closed ("I cannot work"). Produces a busy interval on the server without the
/// reason. Cancellations it causes are `cancelledBy = professional` and never count against a client.
struct TimeBlock: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    var startsAt: Date
    var endsAt: Date
    /// Private. Encrypted at rest.
    var reason: String?

    var interval: DateInterval {
        DateInterval(start: startsAt, end: max(endsAt, startsAt))
    }
}
