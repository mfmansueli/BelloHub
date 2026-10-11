//
//  ClientProfileChip.swift
//  BelloHub
//

import Foundation

/// The small labels under a client's name on her profile: her tags first, then what the history and her settings say.
/// Always words; the screen picks the look.
enum ClientProfileChip: Hashable, Sendable {
    case tag(String)
    case cancelsOften
    case noShows(Int)
    case onlineBookingStopped
    case archived

    static func chips(for client: Client, habits: ClientHabits, tagsByID: [UUID: Tag]) -> [ClientProfileChip] {
        var chips = client.tagIDs.compactMap { tagsByID[$0] }.map { ClientProfileChip.tag($0.name) }
        if habits.cancelsOften { chips.append(.cancelsOften) }
        if habits.noShows > 0 { chips.append(.noShows(habits.noShows)) }
        if client.onlineBookingStopped { chips.append(.onlineBookingStopped) }
        if client.isArchived { chips.append(.archived) }
        return chips
    }
}
