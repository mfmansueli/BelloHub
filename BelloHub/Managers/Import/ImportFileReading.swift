//
//  ImportFileReading.swift
//  BelloHub
//

import Foundation
import UniformTypeIdentifiers

/// Why a spreadsheet could not be read.
enum ImportFileError: Error, Equatable, Sendable {
    case unreadable
    case tooLarge
}

/// How the import turns a file she chose into text. The real reader opens the file the system's file importer returned;
/// a test passes a fake with the text in memory. Excel's own `.xlsx` format is not read in v1: she exports a CSV from
/// Excel or Numbers, and the screen says so.
protocol ImportFileReading: Sendable {
    /// What the system file importer offers her (CSV, tab-separated and plain text).
    var allowedContentTypes: [UTType] { get }

    /// A file to use without showing the file importer. Nil in the real app; UI tests (which cannot drive the system's
    /// Files UI) set it through a DEBUG launch argument.
    var presetFile: URL? { get }

    /// The whole text of the file, whatever its encoding.
    func readText(at url: URL) async throws -> String
}

extension ImportFileReading {
    var presetFile: URL? { nil }
}
