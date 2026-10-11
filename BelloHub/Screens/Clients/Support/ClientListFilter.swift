//
//  ClientListFilter.swift
//  BelloHub
//

import Foundation

/// The chips above the client list. Archived clients are only in `archived`: every other chip leaves them out, so
/// archiving someone really removes her from the lists. Pure: each chip reads facts already on the entry (computed by
/// `HabitsCalculator` and `FollowUpPlanner`), never its own rule.
enum ClientListFilter: Hashable, Sendable {
    case all
    case dueToReturn
    case cancelsOften
    case new
    case tag(UUID)
    case archived

    func matches(_ entry: ClientListEntry) -> Bool {
        if self == .archived { return entry.client.isArchived }
        guard !entry.client.isArchived else { return false }
        switch self {
        case .all: return true
        case .dueToReturn: return entry.isDueToReturn
        case .cancelsOften: return entry.habits.cancelsOften
        case .new: return entry.isNew
        case .tag(let id): return entry.client.tagIDs.contains(id)
        case .archived: return false
        }
    }

    func apply(to entries: [ClientListEntry]) -> [ClientListEntry] {
        self == .all ? entries.filter { !$0.client.isArchived } : entries.filter(matches)
    }

    /// The chips in the order they are shown: the four fixed ones, one per tag in the order she keeps them, and
    /// `archived` only while someone is archived (it is a way back, not a daily tool).
    static func chips(tags: [Tag], hasArchived: Bool) -> [ClientListFilter] {
        [.all, .dueToReturn, .cancelsOften, .new]
            + tags.sorted { ($0.position, $0.name) < ($1.position, $1.name) }.map { .tag($0.id) }
            + (hasArchived ? [.archived] : [])
    }

    /// The suffix of the chip's accessibility identifier: `clients.filter.<identifier>`.
    var identifier: String {
        switch self {
        case .all: "all"
        case .dueToReturn: "dueToReturn"
        case .cancelsOften: "cancelsOften"
        case .new: "new"
        case .tag(let id): "tag.\(id.uuidString)"
        case .archived: "archived"
        }
    }
}
