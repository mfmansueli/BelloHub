//
//  Array+Reorder.swift
//  BelloHub
//

import Foundation

extension Array {
    /// The array after moving the elements at `source` so they end up before the element that was at `destination`
    /// (or at the end when `destination` is `count`). It is the same contract as SwiftUI's `onMove`, kept here so a
    /// pure rule can reorder a list without importing SwiftUI. Indices outside the array are ignored.
    func movingElements(at source: IndexSet, to destination: Int) -> [Element] {
        let valid = source.filter { indices.contains($0) }
        guard !valid.isEmpty else { return self }
        let moved = valid.map { self[$0] }
        let remaining = indices.filter { !valid.contains($0) }.map { self[$0] }
        let before = valid.filter { $0 < destination }.count
        let insertion = Swift.min(Swift.max(destination - before, 0), remaining.count)
        var result = remaining
        result.insert(contentsOf: moved, at: insertion)
        return result
    }
}
