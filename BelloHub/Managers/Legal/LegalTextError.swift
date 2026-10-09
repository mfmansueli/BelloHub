//
//  LegalTextError.swift
//  BelloHub
//

/// What a `LegalTextLibrary` can fail with.
enum LegalTextError: Error, Equatable {
    /// No file for that document, localization and version (a signature from a newer build of the app, for instance).
    case notFound
    /// The file has no header, or its header does not match its name.
    case malformed
}
