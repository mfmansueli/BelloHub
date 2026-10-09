//
//  ClientRowBadge.swift
//  BelloHub
//

import Foundation

/// The one label at the end of a client row. What needs attention comes first ("cancels often"), then "new", then her
/// first tag, so the row never carries more than one word. Always a word, never color alone.
enum ClientRowBadge: Equatable, Sendable {
    case cancelsOften
    case new
    case tag(String)
    case none

    static func make(for entry: ClientListEntry, tagsByID: [UUID: Tag]) -> ClientRowBadge {
        if entry.habits.cancelsOften { return .cancelsOften }
        if entry.isNew { return .new }
        let names = entry.client.tagIDs.compactMap { tagsByID[$0]?.name }
        return names.first.map { .tag($0) } ?? .none
    }
}
