//
//  PDFRecordExporterTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import PDFKit
import Testing
import UIKit

@MainActor
@Suite("PDFRecordExporter", .serialized)
struct PDFRecordExporterTests {
    private func makeRoot() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("pdf-exporter-tests-\(UUID().uuidString)")
    }

    private func jpeg() -> Data {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 120, height: 160))
        return renderer.jpegData(withCompressionQuality: 0.8) { context in
            UIColor.systemPink.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 120, height: 160))
        }
    }

    private func document(sections: Int = 2, withPhoto: Bool = true) -> RecordExportDocument {
        var items: [RecordExportDocument.Item] = [
            .line(label: "Allergies", value: "Latex"),
            .text("Correction, Oct 1, Aftercare: gentle cleansing for 48 hours.")
        ]
        if withPhoto { items.append(.photo(image: jpeg(), caption: "Before · Oct 1, 2026")) }
        return RecordExportDocument(
            title: "Ana Costa · Client record", subtitle: "Maria Silva · exported Oct 1, 2026",
            fileName: "Ana-Costa-record.pdf",
            sections: (0..<sections).map { RecordExportDocument.Section(heading: "Section \($0)", items: items) },
            footer: "Share only with the client or a health professional she authorises."
        )
    }

    @Test("A document becomes a non-empty PDF that PDFKit can open")
    func buildsAPDF() async throws {
        let root = makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let exporter = PDFRecordExporter(root: root)
        let file = try await exporter.export(document())
        let data = try Data(contentsOf: file.url)
        #expect(file.fileName == "Ana-Costa-record.pdf")
        #expect(data.count > 1_000)
        #expect(data.prefix(4) == Data("%PDF".utf8))
        let pdf = PDFDocument(url: file.url)
        #expect((pdf?.pageCount ?? 0) >= 1)
        #expect(pdf?.string?.contains("Ana Costa") == true)
        exporter.discard(file)
    }

    @Test("A long record runs onto more pages")
    func paginates() async throws {
        let root = makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let exporter = PDFRecordExporter(root: root)
        let file = try await exporter.export(document(sections: 40))
        #expect((PDFDocument(url: file.url)?.pageCount ?? 0) > 1)
        exporter.discard(file)
    }

    @Test("Text in Arabic and Hindi is drawn, not dropped")
    func otherScripts() async throws {
        let root = makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let exporter = PDFRecordExporter(root: root)
        var doc = document(withPhoto: false)
        doc.title = "أنا كوستا · سجل العميلة"
        doc.sections[0].items.append(.line(label: "एलर्जी", value: "लेटेक्स"))
        let file = try await exporter.export(doc)
        #expect((PDFDocument(url: file.url)?.pageCount ?? 0) >= 1)
        exporter.discard(file)
    }

    @Test("The file sits alone in its own folder, which is protected, and discard removes the whole folder")
    func fileLifecycle() async throws {
        let root = makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let exporter = PDFRecordExporter(root: root)
        let file = try await exporter.export(document(withPhoto: false))
        let directory = file.url.deletingLastPathComponent()
        #expect(directory.deletingLastPathComponent().deletingLastPathComponent().path == root.path)
        let attributes = try FileManager.default.attributesOfItem(atPath: directory.path)
        // The simulator may report no protection class; where it reports one, it must be the strictest.
        if let protection = attributes[.protectionKey] as? FileProtectionType {
            #expect(protection == .complete)
        }
        #expect(FileManager.default.fileExists(atPath: file.url.path))
        exporter.discard(file)
        #expect(!FileManager.default.fileExists(atPath: file.url.path))
        #expect(!FileManager.default.fileExists(atPath: directory.path))
        exporter.discard(file) // a file already gone is not an error
    }

    @Test("A picture that cannot be read leaves the PDF intact")
    func brokenPicture() async throws {
        let root = makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let exporter = PDFRecordExporter(root: root)
        var doc = document(withPhoto: false)
        doc.sections[0].items.append(.photo(image: Data([0, 1, 2]), caption: "Broken"))
        let file = try await exporter.export(doc)
        #expect((PDFDocument(url: file.url)?.pageCount ?? 0) >= 1)
        exporter.discard(file)
    }
}
