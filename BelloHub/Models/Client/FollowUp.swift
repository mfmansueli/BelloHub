//
//  FollowUp.swift
//  BelloHub
//

import Foundation

/// A client whose recommended return date has arrived.
struct FollowUp: Equatable, Identifiable, Sendable {
    var id: UUID { clientID }
    let clientID: UUID
    let serviceName: String
    let lastVisit: Date
    /// The day the follow-up became due.
    let dueSince: Date
    let daysSinceLastVisit: Int
    /// The service's follow-up interval that made it due, in weeks (the reason she reads, routine-a item 12).
    var intervalWeeks: Int?
}
