//
//  TagRules.swift
//  BelloHub
//

import Foundation

/// The rules of the tag list that have no UI: which names are accepted, which color a new tag starts with, how a new
/// tag is numbered and how the list is renumbered after a drag. One owner for each rule (CLAUDE.md section 2).
enum TagRules {
    /// A tag is a quick label, so its name is short.
    static let maximumNameLength = 30

    /// Whether `raw` can be the name of a tag. A name is unique among tags ignoring case and accents, so renaming
    /// "vip" to "VIP" is fine (`id` is the tag being renamed, whose own name does not count as taken).
    static func check(_ raw: String, among tags: [Tag], editing id: UUID? = nil) -> TagNameCheck {
        let name = OnboardingRules.cleaned(raw)
        guard !name.isEmpty else { return .empty }
        guard name.count <= maximumNameLength else { return .tooLong }
        let others = tags.filter { $0.id != id }.map(\.name)
        guard let accepted = OnboardingRules.acceptedName(name, existing: others) else { return .duplicate }
        return .accepted(accepted)
    }

    /// The color a new tag starts with: the one the fewest tags use, so a row of new tags is not all one color. Ties
    /// go to the first color in the palette's order.
    static func suggestedColor(among tags: [Tag]) -> TagColor {
        let uses = Dictionary(grouping: tags, by: { TagColor(token: $0.colorToken) }).mapValues(\.count)
        return TagColor.allCases.min { (uses[$0] ?? 0) < (uses[$1] ?? 0) } ?? .rose
    }

    /// A new tag, placed after the last one. Nil when the name is not accepted.
    static func makeTag(
        name raw: String, color: TagColor, among tags: [Tag], makeID: () -> UUID = UUID.init
    ) -> Tag? {
        guard let name = check(raw, among: tags).acceptedName else { return nil }
        let next = (tags.map(\.position).max() ?? -1) + 1
        return Tag(id: makeID(), name: name, colorToken: color.token, position: next)
    }

    /// The tag renamed and recolored. Nil when the new name is not accepted.
    static func updating(_ tag: Tag, name raw: String, color: TagColor, among tags: [Tag]) -> Tag? {
        guard let name = check(raw, among: tags, editing: tag.id).acceptedName else { return nil }
        var updated = tag
        updated.name = name
        updated.colorToken = color.token
        return updated
    }

    /// The list after a drag, with positions renumbered `0...n-1`. `source` and `destination` follow `onMove`.
    static func moving(_ tags: [Tag], from source: IndexSet, to destination: Int) -> [Tag] {
        renumbered(Tag.ordered(tags).movingElements(at: source, to: destination))
    }

    /// Positions rewritten to `0...n-1` in the order given.
    static func renumbered(_ tags: [Tag]) -> [Tag] {
        tags.enumerated().map { index, tag in
            var numbered = tag
            numbered.position = index
            return numbered
        }
    }

    /// The tags of `after` whose stored values differ from `before`: all a save has to write.
    static func changed(from before: [Tag], to after: [Tag]) -> [Tag] {
        let previous = Dictionary(uniqueKeysWithValues: before.map { ($0.id, $0) })
        return after.filter { previous[$0.id] != $0 }
    }
}
