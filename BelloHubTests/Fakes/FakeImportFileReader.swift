//
//  FakeImportFileReader.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import os
import UniformTypeIdentifiers

/// A file reader a test scripts: the text it returns (or the error it throws) and the URLs it was asked to read.
final class FakeImportFileReader: ImportFileReading, Sendable {
    private struct State {
        var text = ""
        var error: ImportFileError?
        var read: [URL] = []
        var preset: URL?
    }

    private let state = OSAllocatedUnfairLock(initialState: State())

    init(text: String = "", error: ImportFileError? = nil, presetFile: URL? = nil) {
        state.withLock {
            $0.text = text
            $0.error = error
            $0.preset = presetFile
        }
    }

    var text: String {
        get { state.withLock { $0.text } }
        set { state.withLock { $0.text = newValue } }
    }

    var error: ImportFileError? {
        get { state.withLock { $0.error } }
        set { state.withLock { $0.error = newValue } }
    }

    var readURLs: [URL] { state.withLock { $0.read } }
    var allowedContentTypes: [UTType] { [.commaSeparatedText] }
    var presetFile: URL? { state.withLock { $0.preset } }

    func readText(at url: URL) async throws -> String {
        let (text, error) = state.withLock { state -> (String, ImportFileError?) in
            state.read.append(url)
            return (state.text, state.error)
        }
        if let error { throw error }
        return text
    }
}
