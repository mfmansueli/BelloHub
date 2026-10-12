//
//  OptionNameRules.swift
//  BelloHub
//

import Foundation

/// How option names are compared and suggested. Two names are the same option when they differ only by spaces or
/// letter case ("Gel  polish" and "gel polish"). Accents are kept apart on purpose: in some languages they change
/// the meaning, so "Pêche" and "Peche" are never merged on their own. Suggestions are looser (accents and case
/// ignored) because they only propose; she decides. Pure.
enum OptionNameRules {
    static let maxLength = 60

    /// Trimmed, with runs of spaces and line breaks collapsed to one space.
    static func normalized(_ name: String) -> String {
        name.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    /// The comparison key: normalized and lowercased, accents kept.
    static func key(_ name: String) -> String {
        normalized(name).lowercased()
    }

    /// The existing name that is the same option as `name`, if any.
    static func match(_ name: String, in names: [String]) -> String? {
        let wanted = key(name)
        guard !wanted.isEmpty else { return nil }
        return names.first { key($0) == wanted }
    }

    /// Names that contain what she typed, ignoring accents and case; the ones that start with it come first. An
    /// empty query offers everything, in the given order.
    static func suggestions(for query: String, in names: [String], limit: Int = 8) -> [String] {
        let typed = normalized(query)
        guard !typed.isEmpty else { return Array(names.prefix(limit)) }
        let options: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive]
        let found = names.filter { $0.range(of: typed, options: options) != nil }
        let starts = found.filter { $0.range(of: typed, options: options.union(.anchored)) != nil }
        let others = found.filter { !starts.contains($0) }
        return Array((starts + others).prefix(limit))
    }

    /// Whether `name` can be saved: not empty, not too long.
    static func isValid(_ name: String) -> Bool {
        let cleaned = normalized(name)
        return !cleaned.isEmpty && cleaned.count <= maxLength
    }
}
