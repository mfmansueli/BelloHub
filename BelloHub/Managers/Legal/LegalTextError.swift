//
//  LegalTextError.swift
//  BelloHub
//

/// What a `LegalNoticeLibrary` can fail with.
enum LegalTextError: Error, Equatable {
    /// No file for that notice in that localization, nor in English.
    case notFound
    /// The file has no header, or its header does not match its name.
    case malformed
}
