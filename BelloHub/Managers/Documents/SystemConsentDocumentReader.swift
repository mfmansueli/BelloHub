//
//  SystemConsentDocumentReader.swift
//  BelloHub
//

import Foundation
import UniformTypeIdentifiers

/// Reads the file the system's file importer returned. Access to the security-scoped URL is opened for the read and
/// closed right after, and the bytes are copied out: nothing keeps the file, its path or its bookmark. The bytes go to
/// the vault sealed; they are never written back anywhere.
struct SystemConsentDocumentReader: ConsentDocumentReading {
    var allowedContentTypes: [UTType] { [.pdf, .image] }

    func readFile(at url: URL) async throws -> ConsentDocumentFile {
        try await Task.detached(priority: .userInitiated) {
            let isScoped = url.startAccessingSecurityScopedResource()
            defer { if isScoped { url.stopAccessingSecurityScopedResource() } }
            let values = try? url.resourceValues(forKeys: [.fileSizeKey, .contentTypeKey])
            if let size = values?.fileSize, size > ConsentDocument.maximumBytes {
                throw ConsentDocumentError.tooLarge
            }
            let type = values?.contentType ?? UTType(filenameExtension: url.pathExtension) ?? .data
            guard type.conforms(to: .pdf) || type.conforms(to: .image) else {
                throw ConsentDocumentError.unsupportedType
            }
            guard let data = try? Data(contentsOf: url, options: .mappedIfSafe) else {
                throw ConsentDocumentError.unreadable
            }
            guard data.count <= ConsentDocument.maximumBytes else { throw ConsentDocumentError.tooLarge }
            return ConsentDocumentFile(fileName: url.lastPathComponent, contentType: type, data: Data(data))
        }.value
    }
}
