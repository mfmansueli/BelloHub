//
//  FieldEditorMode.swift
//  BelloHub
//

/// What the field sheet is for: a new field of hers, or one she is renaming or deleting. It is the `item` of the
/// sheet, so SwiftUI builds a fresh sheet (and fresh field state) for each field.
enum FieldEditorMode: Identifiable, Equatable, Sendable {
    case add
    case edit(RecordFieldSetting)

    var id: String {
        switch self {
        case .add: "add"
        case .edit(let field): field.key
        }
    }

    /// The field being edited, nil when adding.
    var field: RecordFieldSetting? {
        if case .edit(let field) = self { return field }
        return nil
    }
}
