//
//  AddOnFormIssue.swift
//  BelloHub
//

/// Why the add-on form cannot be saved yet.
enum AddOnFormIssue: Equatable, Sendable {
    case nameEmpty
    case nameTooLong
    case nameTaken
    /// The price field holds something that is not an amount.
    case priceInvalid
}
