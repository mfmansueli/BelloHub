//
//  FakeDocumentPrinter.swift
//  BelloHubTests
//

@testable import BelloHub

/// Remembers what the screen sent to the printer instead of showing the print sheet.
@MainActor
final class FakeDocumentPrinter: DocumentPrinting {
    private(set) var jobs: [(text: String, jobName: String)] = []

    func printDocument(text: String, jobName: String) {
        jobs.append((text, jobName))
    }
}
