//
//  RecordExporting.swift
//  BelloHub
//

import Foundation

/// Turns a `RecordExportDocument` into a file she can share (4.10). A protocol because PDF rendering is a
/// technology the owner refines after v1 (D53): the screen only knows "give me a file" and "I am done with it".
@MainActor
protocol RecordExporting: AnyObject {
    /// Writes the document to a file in a protected temporary directory. Throws `RecordExportError` when it cannot.
    func export(_ document: RecordExportDocument) async throws -> ExportedFile
    /// Deletes the file. Called after the share sheet closes, and again when the screen goes away; a file that is
    /// already gone is not an error.
    func discard(_ file: ExportedFile)
}
