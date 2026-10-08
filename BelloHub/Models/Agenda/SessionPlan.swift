//
//  SessionPlan.swift
//  BelloHub
//

import Foundation

/// A series of sessions toward one goal ("Skin barrier repair", 6 sessions every 4 weeks). No prices, just the rhythm.
struct SessionPlan: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    var clientID: UUID
    var name: String
    var totalSessions: Int
    var intervalWeeks: Int
    var startDate: Date
    var remindToRebook: Bool
}
