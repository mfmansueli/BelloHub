//
//  PositionRules.swift
//  BelloHub
//

import Foundation

/// How a hand-ordered list (services, add-ons, products, credentials) is numbered and renumbered. One owner for the
/// rule, so a drag behaves the same on every screen and a save only writes what changed.
enum PositionRules {
    /// The position a new item takes: after the last one.
    static func next<Item: Positioned>(after items: [Item]) -> Int {
        (items.map(\.position).max() ?? -1) + 1
    }

    /// The list after a drag, with positions renumbered `0...n-1`. `source` and `destination` follow SwiftUI's
    /// `onMove`. `items` must already be in display order.
    static func moving<Item: Positioned>(_ items: [Item], from source: IndexSet, to destination: Int) -> [Item] {
        renumbered(items.movingElements(at: source, to: destination))
    }

    /// Positions rewritten to `0...n-1` in the order given.
    static func renumbered<Item: Positioned>(_ items: [Item]) -> [Item] {
        items.enumerated().map { index, item in
            var numbered = item
            numbered.position = index
            return numbered
        }
    }

    /// The items of `after` whose stored values differ from `before`: all a save has to write.
    static func changed<Item: Positioned>(from before: [Item], to after: [Item]) -> [Item] {
        let previous = Dictionary(before.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        return after.filter { previous[$0.id] != $0 }
    }
}
