//
//  CredentialFormIssue.swift
//  BelloHub
//

/// Why the credential form cannot be saved yet.
enum CredentialFormIssue: Equatable, Sendable {
    case titleEmpty
    case titleTooLong
    case institutionTooLong
    /// The year is not a four-digit year between 1950 and next year.
    case yearInvalid
}
