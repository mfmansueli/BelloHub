//
//  FakeRecordExporter.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation

/// An exporter that remembers what it was given and writes nothing, or fails.
@MainActor
final class FakeRecordExporter: RecordExporting {
    var fails = false
    private(set) var exported: [RecordExportDocument] = []
    private(set) var discarded: [ExportedFile] = []

    func export(_ document: RecordExportDocument) async throws -> ExportedFile {
        if fails { throw RecordExportError.cannotWrite }
        exported.append(document)
        return ExportedFile(url: URL(fileURLWithPath: "/tmp/fake/\(document.fileName)"))
    }

    func discard(_ file: ExportedFile) {
        discarded.append(file)
    }
}
