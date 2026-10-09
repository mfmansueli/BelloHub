//
//  SlugIssue.swift
//  BelloHub
//

/// Why an address cannot be used, as `BookingSlug.validate` reports it. The server applies the same rules and answers
/// `invalid` or `reserved` for the same cases.
enum SlugIssue: Equatable, Sendable {
    case tooShort
    case tooLong
    /// A character outside a to z, 0 to 9 and the hyphen.
    case characters
    /// Starts or ends with a hyphen.
    case hyphenEdges
    case doubleHyphen
    case reserved
}
