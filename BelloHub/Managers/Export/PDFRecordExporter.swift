//
//  PDFRecordExporter.swift
//  BelloHub
//

import UIKit

/// The default `RecordExporting`: a plain, honest PDF made from styled text and pictures with UIKit's print renderer
/// (no layout engine to maintain). The owner replaces it after v1 (D53). The file lives in its own temporary directory
/// with complete file protection, so it is unreadable while the phone is locked, and it is deleted after sharing.
@MainActor
final class PDFRecordExporter: RecordExporting {
    private static let page = CGRect(x: 0, y: 0, width: 595.2, height: 841.8) // A4 in points
    private static let margin: CGFloat = 48
    private nonisolated static let directoryName = "BelloHubExports"

    private let root: URL

    /// Not main-actor isolated so it can be the default value of an environment entry; `root` is a plain URL.
    nonisolated init(root: URL = FileManager.default.temporaryDirectory) {
        self.root = root.appendingPathComponent(Self.directoryName, isDirectory: true)
    }

    private var fileManager: FileManager { .default }

    func export(_ document: RecordExportDocument) async throws -> ExportedFile {
        let data = try render(document)
        let directory = root.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let url = directory.appendingPathComponent(document.fileName)
        do {
            try fileManager.createDirectory(
                at: directory, withIntermediateDirectories: true,
                attributes: [.protectionKey: FileProtectionType.complete]
            )
            try data.write(to: url, options: [.atomic, .completeFileProtection])
        } catch {
            throw RecordExportError.cannotWrite
        }
        return ExportedFile(url: url)
    }

    func discard(_ file: ExportedFile) {
        // The file sits alone in a directory named for the export, so the whole directory goes.
        let directory = file.url.deletingLastPathComponent()
        guard directory.deletingLastPathComponent().lastPathComponent == Self.directoryName else {
            try? fileManager.removeItem(at: file.url)
            return
        }
        try? fileManager.removeItem(at: directory)
    }

    // MARK: - Drawing

    private func render(_ document: RecordExportDocument) throws -> Data {
        let renderer = UIPrintPageRenderer()
        renderer.addPrintFormatter(UISimpleTextPrintFormatter(attributedText: text(for: document)), startingAtPageAt: 0)
        let printable = Self.page.insetBy(dx: Self.margin, dy: Self.margin)
        renderer.setValue(NSValue(cgRect: Self.page), forKey: "paperRect")
        renderer.setValue(NSValue(cgRect: printable), forKey: "printableRect")

        let output = NSMutableData()
        UIGraphicsBeginPDFContextToData(output, Self.page, [kCGPDFContextTitle as String: document.title])
        defer { UIGraphicsEndPDFContext() }
        renderer.prepare(forDrawingPages: NSRange(location: 0, length: max(renderer.numberOfPages, 1)))
        guard renderer.numberOfPages > 0 else { throw RecordExportError.nothingToDraw }
        let bounds = UIGraphicsGetPDFContextBounds()
        for index in 0..<renderer.numberOfPages {
            UIGraphicsBeginPDFPage()
            renderer.drawPage(at: index, in: bounds)
        }
        return output as Data
    }

    private func text(for document: RecordExportDocument) -> NSAttributedString {
        let result = NSMutableAttributedString()
        func add(_ string: String, font: UIFont, color: UIColor = .black, after: CGFloat = 4) {
            let style = NSMutableParagraphStyle()
            style.baseWritingDirection = .natural
            style.alignment = .natural
            style.paragraphSpacing = after
            result.append(NSAttributedString(string: string + "\n", attributes: [
                .font: font, .foregroundColor: color, .paragraphStyle: style
            ]))
        }
        add(document.title, font: .systemFont(ofSize: 22, weight: .bold), after: 2)
        add(document.subtitle, font: .systemFont(ofSize: 11), color: .darkGray, after: 16)
        for section in document.sections {
            add(section.heading, font: .systemFont(ofSize: 15, weight: .bold), after: 6)
            for item in section.items {
                switch item {
                case .line(let label, let value):
                    result.append(line(label: label, value: value))
                case .text(let paragraph):
                    add(paragraph, font: .systemFont(ofSize: 11))
                case .photo(let image, let caption):
                    if let attachment = photo(image) { result.append(attachment) }
                    add(caption, font: .systemFont(ofSize: 10), color: .darkGray, after: 10)
                }
            }
            add("", font: .systemFont(ofSize: 6), after: 8)
        }
        add(document.footer, font: .italicSystemFont(ofSize: 10), color: .darkGray)
        return result
    }

    private func line(label: String, value: String) -> NSAttributedString {
        let style = NSMutableParagraphStyle()
        style.baseWritingDirection = .natural
        style.alignment = .natural
        style.paragraphSpacing = 4
        let line = NSMutableAttributedString(string: label + ": ", attributes: [
            .font: UIFont.systemFont(ofSize: 11, weight: .semibold), .foregroundColor: UIColor.black,
            .paragraphStyle: style
        ])
        line.append(NSAttributedString(string: value + "\n", attributes: [
            .font: UIFont.systemFont(ofSize: 11), .foregroundColor: UIColor.black, .paragraphStyle: style
        ]))
        return line
    }

    /// A picture at most 220 pt wide and 260 pt high, on its own line. A picture that cannot be read is left out.
    private func photo(_ data: Data) -> NSAttributedString? {
        guard let image = UIImage(data: data), image.size.width > 0, image.size.height > 0 else { return nil }
        let scale = min(220 / image.size.width, 260 / image.size.height, 1)
        let attachment = NSTextAttachment()
        attachment.image = image
        attachment.bounds = CGRect(x: 0, y: 0, width: image.size.width * scale, height: image.size.height * scale)
        let result = NSMutableAttributedString(attachment: attachment)
        result.append(NSAttributedString(string: "\n"))
        return result
    }
}
