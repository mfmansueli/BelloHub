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
}
