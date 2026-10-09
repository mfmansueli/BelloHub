//
//  ServiceFormIssue.swift
//  BelloHub
//

/// Why the service form cannot be saved yet, or what to tell her about a field.
enum ServiceFormIssue: Equatable, Sendable {
    case nameEmpty
    case nameTooLong
    case nameTaken
    /// The price field holds something that is not an amount.
    case priceInvalid
}
