//
//  CredentialEditorMode.swift
//  BelloHub
//

import Foundation

/// What the credential sheet is for: a new credential, or one she is changing or deleting. It is the `item` of the
/// sheet, so SwiftUI builds a fresh form for each credential.
enum CredentialEditorMode: Identifiable, Equatable, Sendable {
    case add
    case edit(Credential)

    var id: String {
        switch self {
        case .add: "add"
        case .edit(let credential): credential.id.uuidString
        }
    }

    /// The credential being edited, nil when adding.
    var credential: Credential? {
        if case .edit(let credential) = self { return credential }
        return nil
    }
}
