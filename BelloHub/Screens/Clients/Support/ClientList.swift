//
//  ClientList.swift
//  BelloHub
//

import Foundation

/// Everything the Clients screen shows before a filter or a search narrows it.
struct ClientList: Equatable, Sendable {
    /// Every client, archived ones included, in reading order (`ClientSort`).
    let entries: [ClientListEntry]
    /// Clients with no visit for two months and nothing booked, longest away first (`FollowUpPlanner`).
    let winBack: [WinBackCandidate]

    static let empty = ClientList(entries: [], winBack: [])

    var hasArchived: Bool { entries.contains { $0.client.isArchived } }
}
