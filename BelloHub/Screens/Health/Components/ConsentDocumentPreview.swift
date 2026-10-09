//
//  ConsentDocumentPreview.swift
//  BelloHub
//

import SwiftUI
import UniformTypeIdentifiers

/// The photo or file kept with a consent record, shown in the sheet: a picture is drawn from its bytes, a PDF is
/// rendered by PDFKit from memory, and any other file shows its name. Nothing is written to disk to show it.
struct ConsentDocumentPreview: View {
    let document: ConsentDocument

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            content
                .frame(maxWidth: .infinity)
                .frame(height: 260)
                .clipShape(RoundedRectangle(cornerRadius: Radius.tile, style: .continuous))
                .accessibilityHidden(true)
            Text(verbatim: caption)
                .font(Typography.footnote)
                .foregroundStyle(Palette.ink2)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(document.kind == .photo ? "consent.document.photo" : "consent.document.file"))
        .accessibilityValue(Text(verbatim: caption))
        .accessibilityIdentifier("consent.documentPreview")
    }

    @ViewBuilder
    private var content: some View {
        if document.kind == .photo {
            DataImage(data: document.data)
        } else if UTType(document.contentType)?.conforms(to: .pdf) == true {
            PDFDocumentView(data: document.data)
        } else {
            ZStack {
                Palette.sunken
                Image(icon: .document).font(.system(size: 34)).foregroundStyle(Palette.ink2)
            }
        }
    }

    /// "scan.pdf · 1.2 MB", or just the size for a photo.
    private var caption: String {
        let size = ByteCountFormatter.string(fromByteCount: Int64(document.data.count), countStyle: .file)
        if let name = document.fileName, !name.isEmpty { return "\(name) · \(size)" }
        return size
    }
}
