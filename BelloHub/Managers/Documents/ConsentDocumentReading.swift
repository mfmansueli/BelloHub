//
//  ConsentDocumentReading.swift
//  BelloHub
//

import Foundation
import UniformTypeIdentifiers

/// Why a chosen file cannot become a consent document.
enum ConsentDocumentError: Error, Equatable, Sendable {
    case unreadable
    case tooLarge
    case unsupportedType
}

/// What the system's file importer gave back, read into memory.
struct ConsentDocumentFile: Equatable, Sendable {
    var fileName: String
    var contentType: UTType
    var data: Data
}

/// How the consent sheet turns a file she chose (a PDF scan or a picture of the signed paper) into bytes. The real
/// reader opens the security-scoped URL the file importer returned; a test passes a fake with the bytes in memory.
protocol ConsentDocumentReading: Sendable {
    /// What the file importer offers: PDF files and images.
    var allowedContentTypes: [UTType] { get }

    func readFile(at url: URL) async throws -> ConsentDocumentFile
}
