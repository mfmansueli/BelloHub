//
//  ProductFormIssue.swift
//  BelloHub
//

/// Why the product form cannot be saved yet.
enum ProductFormIssue: Equatable, Sendable {
    case nameEmpty
    case nameTooLong
    /// The same name from the same brand is already in the list.
    case nameTaken
    case brandTooLong
    case noteTooLong
}
