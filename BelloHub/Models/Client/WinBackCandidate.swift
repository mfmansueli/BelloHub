//
//  WinBackCandidate.swift
//  BelloHub
//

import Foundation

/// A client with no visit for a long time and nothing booked.
struct WinBackCandidate: Equatable, Identifiable, Sendable {
    var id: UUID { clientID }
    let clientID: UUID
    let lastVisit: Date
    let daysSinceLastVisit: Int
}
