//
//  ClientSearch+List.swift
//  BelloHub
//

import Foundation

extension ClientSearch {
    /// The list entries that match `query`; all of them for an empty query. Order is kept.
    static func filter(_ entries: [ClientListEntry], query: String, tags: [Tag]) -> [ClientListEntry] {
        filter(entries, query: query, tags: tags, client: \.client)
    }
}
