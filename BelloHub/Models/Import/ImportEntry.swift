//
//  ImportEntry.swift
//  BelloHub
//

import Foundation

/// A candidate after the rules: either a client ready to be saved, or a row that cannot be, with the reason.
struct ImportEntry: Identifiable, Equatable, Sendable {
    enum Outcome: Equatable, Sendable {
        case ready(Client)
        case malformed(ImportRowIssue)
    }

    /// The candidate's id, so a selection survives rebuilding the entries.
    let id: String
    /// The name as it will be listed ("" when the source had none).
    let displayName: String
    /// The row number of a spreadsheet row, for the "Row 12" label of a row without a name.
    let rowNumber: Int?
    let outcome: Outcome

    var client: Client? {
        if case .ready(let client) = outcome { return client }
        return nil
    }

    var issue: ImportRowIssue? {
        if case .malformed(let issue) = outcome { return issue }
        return nil
    }

    var isReady: Bool { client != nil }
}
