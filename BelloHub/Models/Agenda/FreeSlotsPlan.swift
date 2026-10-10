//
//  FreeSlotsPlan.swift
//  BelloHub
//

import Foundation

/// The free starts of one day (D56): every one of them, and the ones to show first. With the day kept compact,
/// `recommended` holds the starts that leave no dead gap (or, in a gap where every start leaves one, the least dead
/// time); otherwise it equals `all`. Every start in `all` can be booked.
struct FreeSlotsPlan: Hashable, Sendable {
    var all: [Date]
    var recommended: [Date]

    static let empty = FreeSlotsPlan(all: [], recommended: [])

    /// The free starts that are not recommended, in time order ("Show all times").
    var more: [Date] {
        let shown = Set(recommended)
        return all.filter { !shown.contains($0) }
    }
}
