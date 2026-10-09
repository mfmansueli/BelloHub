//
//  AddOnEditorMode.swift
//  BelloHub
//

import Foundation

/// What the add-on sheet is for: a new add-on, or one she is changing or deleting. It is the `item` of the sheet, so
/// SwiftUI builds a fresh form for each add-on.
enum AddOnEditorMode: Identifiable, Equatable, Sendable {
    case add
    case edit(AddOn)

    var id: String {
        switch self {
        case .add: "add"
        case .edit(let addOn): addOn.id.uuidString
        }
    }

    /// The add-on being edited, nil when adding.
    var addOn: AddOn? {
        if case .edit(let addOn) = self { return addOn }
        return nil
    }
}
