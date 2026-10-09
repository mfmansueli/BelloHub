//
//  FakeConsentDocumentReader.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import UniformTypeIdentifiers

/// A document reader with the bytes in memory, keyed by the URL's last path component, or one that fails.
struct FakeConsentDocumentReader: ConsentDocumentReading {
    var files: [String: ConsentDocumentFile] = [:]
    var failure: ConsentDocumentError?

    var allowedContentTypes: [UTType] { [.pdf, .image] }

    func readFile(at url: URL) async throws -> ConsentDocumentFile {
        if let failure { throw failure }
        guard let file = files[url.lastPathComponent] else { throw ConsentDocumentError.unreadable }
        return file
    }

    static func pdf(named name: String = "scan.pdf", bytes: Int = 1_024) -> ConsentDocumentFile {
        ConsentDocumentFile(fileName: name, contentType: .pdf, data: Data(repeating: 0x25, count: bytes))
    }

    static func image(named name: String = "paper.jpg") -> ConsentDocumentFile {
        ConsentDocumentFile(fileName: name, contentType: .jpeg, data: Data([0xFF, 0xD8, 0xFF, 0xD9]))
    }
}
