//
//  TagNameCheck.swift
//  BelloHub
//

/// What `TagRules.check` says about a name she typed for a tag.
enum TagNameCheck: Equatable, Sendable {
    /// Fine; carries the name to store (whitespace collapsed).
    case accepted(String)
    case empty
    case tooLong
    /// Another tag already has this name, ignoring case and accents.
    case duplicate

    var acceptedName: String? {
        if case .accepted(let name) = self { return name }
        return nil
    }
}
