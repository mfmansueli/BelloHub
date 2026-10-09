//
//  RecordFieldEntry.swift
//  BelloHub
//

import Foundation

/// What she wrote in one field of her record template for one visit. It is keyed by the template field's `key`
/// (stable across languages and renames) and carries the name the field had when it was saved, so a record still
/// reads correctly after she renames, switches off or deletes the field (docs/agent-notes/tags-record-template.md).
/// Encrypted at rest with the rest of the record's text.
struct RecordFieldEntry: Identifiable, Hashable, Codable, Sendable {
    /// Separates the options of a multi-choice answer. An option never holds a line break (she lists one per line).
    static let optionSeparator = "\n"
    static let yes = "yes"
    static let no = "no"

    var key: String
    /// The field's name when the record was saved.
    var name: String
    var kind: RecordFieldKind
    /// The answer. Free text and a choice as written; a number as typed (`2.5`, the unit is in `unit`); yes or no as
    /// `yes` / `no`; several options joined with `optionSeparator`.
    var value: String
    /// What a number is measured in, as it was when saved.
    var unit: String?

    var id: String { key }

    /// The options of a multi-choice answer, in the order she picked them.
    var options: [String] {
        value.components(separatedBy: Self.optionSeparator).filter { !$0.isEmpty }
    }
}
