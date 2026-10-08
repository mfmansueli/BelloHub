//
//  RecordFieldIssue.swift
//  BelloHub
//

/// Why a field she is adding or editing cannot be saved yet. The first problem found wins, in the order of the sheet
/// (name, options, unit), so the message sits under the part of the form that needs fixing.
enum RecordFieldIssue: Error, Equatable, Sendable {
    case nameEmpty
    case nameTooLong
    /// Another field of the same profession (a catalog field or one of hers) has this name, ignoring case and accents.
    case nameTaken
    case tooFewOptions
    case tooManyOptions
    case optionTooLong
    case unitTooLong
    /// She already has the most fields of her own a profession can hold.
    case limitReached
    /// The field to edit is not in the template (another device deleted it).
    case notFound

    /// The part of the sheet the issue belongs to, so the message is shown under it.
    enum Part: Equatable, Sendable {
        case name
        case options
        case unit
        case general
    }

    var part: Part {
        switch self {
        case .nameEmpty, .nameTooLong, .nameTaken: .name
        case .tooFewOptions, .tooManyOptions, .optionTooLong: .options
        case .unitTooLong: .unit
        case .limitReached, .notFound: .general
        }
    }
}
