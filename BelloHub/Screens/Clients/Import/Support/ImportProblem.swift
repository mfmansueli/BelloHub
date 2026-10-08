//
//  ImportProblem.swift
//  BelloHub
//

import SwiftUI

/// What went wrong in the import, in the words she sees: a line that says what happened and one that says what to do
/// next (docs/01-PRODUCT.md voice), never a system error.
enum ImportProblem: Equatable, Sendable {
    /// The file could not be opened or is too large to be a client list.
    case fileUnreadable
    /// The file opened but has no rows under the header.
    case fileEmpty
    /// A restriction on this iPhone keeps apps out of the contacts.
    case contactsRestricted
    /// The import could not be saved (the vault is unavailable or full).
    case importFailed
    /// The region table did not load, so numbers cannot be read. Should never happen in a built app.
    case unavailable

    var title: LocalizedStringKey {
        switch self {
        case .fileUnreadable: "import.problem.fileUnreadable.title"
        case .fileEmpty: "import.problem.fileEmpty.title"
        case .contactsRestricted: "import.problem.contactsRestricted.title"
        case .importFailed: "import.problem.importFailed.title"
        case .unavailable: "import.problem.unavailable.title"
        }
    }

    var message: LocalizedStringKey {
        switch self {
        case .fileUnreadable: "import.problem.fileUnreadable.message"
        case .fileEmpty: "import.problem.fileEmpty.message"
        case .contactsRestricted: "import.problem.contactsRestricted.message"
        case .importFailed: "import.problem.importFailed.message"
        case .unavailable: "import.problem.unavailable.message"
        }
    }
}
