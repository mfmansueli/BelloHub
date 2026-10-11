//
//  SystemImportFileReader.swift
//  BelloHub
//

import Foundation
import UniformTypeIdentifiers

/// Reads the file the system's file importer returned. The URL is security-scoped, so access is opened for the read and
/// closed right after, and the bytes are copied out: nothing keeps the file or its path.
struct SystemImportFileReader: ImportFileReading {
    /// A spreadsheet of tens of thousands of clients is a few megabytes; anything near this size is not a client list.
    static let maximumBytes = 20 * 1_024 * 1_024

    var allowedContentTypes: [UTType] { [.commaSeparatedText, .tabSeparatedText, .plainText] }

    func readText(at url: URL) async throws -> String {
        try await Task.detached(priority: .userInitiated) {
            let isScoped = url.startAccessingSecurityScopedResource()
            defer { if isScoped { url.stopAccessingSecurityScopedResource() } }
            if let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize, size > Self.maximumBytes {
                throw ImportFileError.tooLarge
            }
            guard let data = try? Data(contentsOf: url, options: .mappedIfSafe) else {
                throw ImportFileError.unreadable
            }
            guard data.count <= Self.maximumBytes else { throw ImportFileError.tooLarge }
            return ImportTextDecoder.decode(data)
        }.value
    }
}
