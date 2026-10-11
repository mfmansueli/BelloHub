//
//  ClientSort.swift
//  BelloHub
//

import Foundation

/// The order of the client list: by name, the way people read names (`localizedStandardCompare`: "María" sits with the
/// Ms, "Ana 2" before "Ana 10", case and accents ignored). The one owner of the order: the repository's own ordering
/// is not relied on.
enum ClientSort {
    static func areInIncreasingOrder(_ left: Client, _ right: Client) -> Bool {
        switch left.name.localizedStandardCompare(right.name) {
        case .orderedAscending: true
        case .orderedDescending: false
        // Two people with the same name keep a stable order from run to run.
        case .orderedSame: left.id.uuidString < right.id.uuidString
        }
    }

    static func sorted(_ entries: [ClientListEntry]) -> [ClientListEntry] {
        entries.sorted { areInIncreasingOrder($0.client, $1.client) }
    }

    static func sorted(_ clients: [Client]) -> [Client] {
        clients.sorted(by: areInIncreasingOrder)
    }
}
