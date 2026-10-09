//
//  Tag+Ordering.swift
//  BelloHub
//

import Foundation

extension Tag {
    /// The order tags are listed in everywhere: by `position`, then by name so two tags that share a position (two
    /// devices adding at once) still list the same way on both.
    static func ordered(_ tags: [Tag]) -> [Tag] {
        tags.sorted { ($0.position, $0.name) < ($1.position, $1.name) }
    }
}
