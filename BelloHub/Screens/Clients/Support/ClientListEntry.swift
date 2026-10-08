//
//  ClientListEntry.swift
//  BelloHub
//

import Foundation

/// A client as the list needs her: the client and what her history says, computed once when the vault changes so that
/// filtering, searching and scrolling never recompute habits.
struct ClientListEntry: Identifiable, Equatable, Sendable {
    let client: Client
    let habits: ClientHabits
    let summary: ClientRowSummary
    /// Her last visit is old enough for the service's follow-up and nothing is booked (`FollowUpPlanner`).
    let isDueToReturn: Bool
    /// She has not had a completed visit yet.
    let isNew: Bool

    var id: UUID { client.id }
}
