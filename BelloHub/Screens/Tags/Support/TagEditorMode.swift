//
//  TagEditorMode.swift
//  BelloHub
//

import Foundation

/// What the tag sheet is for: a new tag, or one she is renaming, recoloring or deleting. It is the `item` of the
/// sheet, so SwiftUI builds a fresh sheet (and fresh field state) for each tag.
enum TagEditorMode: Identifiable, Equatable, Sendable {
    case add
    case edit(Tag)

    var id: String {
        switch self {
        case .add: "add"
        case .edit(let tag): tag.id.uuidString
        }
    }

    /// The tag being edited, nil when adding.
    var tag: Tag? {
        if case .edit(let tag) = self { return tag }
        return nil
    }
}
