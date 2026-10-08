//
//  KnowledgeListRules.swift
//  BelloHub
//

import Foundation

/// How an entry is added to one of the knowledge lists (sensitivities, preferences, recurring requests). Pure.
enum KnowledgeListRules {
    enum Addition: Equatable, Sendable {
        case added([String])
        /// Only spaces: nothing to add.
        case empty
        /// The list already says this (ignoring case and accents): the entry is not repeated.
        case duplicate
    }

    /// `list` with `text` added at the end, trimmed.
    static func adding(_ text: String, to list: [String]) -> Addition {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .empty }
        let key = ClientMerger.comparisonKey(trimmed)
        guard !list.contains(where: { ClientMerger.comparisonKey($0) == key }) else { return .duplicate }
        return .added(list + [trimmed])
    }

    /// `list` without the entries at `offsets` (what a swipe or the delete handle asks for).
    static func removing(_ offsets: IndexSet, from list: [String]) -> [String] {
        list.enumerated().filter { !offsets.contains($0.offset) }.map(\.element)
    }

    /// `list` with the entries at `source` moved so they sit before the entry that was at `destination`, in the
    /// numbering of the list before the move (the convention of the system's `onMove`; `count` means the end).
    static func moving(_ source: IndexSet, to destination: Int, in list: [String]) -> [String] {
        let moved = source.filter { list.indices.contains($0) }.map { list[$0] }
        var rest = list.enumerated().filter { !source.contains($0.offset) }.map(\.element)
        let removedBefore = source.filter { $0 < destination }.count
        let target = min(max(destination - removedBefore, 0), rest.count)
        rest.insert(contentsOf: moved, at: target)
        return rest
    }
}
