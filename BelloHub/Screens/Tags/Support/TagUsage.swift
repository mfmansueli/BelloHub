//
//  TagUsage.swift
//  BelloHub
//

import Foundation

/// How many clients carry each tag ("2 people" under a tag, and "2 people will lose this tag" before a delete).
/// Archived clients count: deleting the tag removes it from them too, so the number she is warned about matches what
/// happens.
enum TagUsage {
    /// One entry for every tag in `tags`, zero when nobody has it. A tag id on a client that no longer exists in
    /// `tags` is ignored, and a client that lists the same tag twice counts once.
    static func counts(tags: [Tag], clients: [Client]) -> [UUID: Int] {
        var counts = Dictionary(uniqueKeysWithValues: tags.map { ($0.id, 0) })
        for client in clients {
            for id in Set(client.tagIDs) where counts[id] != nil {
                counts[id, default: 0] += 1
            }
        }
        return counts
    }
}
