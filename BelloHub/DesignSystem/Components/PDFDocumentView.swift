//
//  PDFDocumentView.swift
//  BelloHub
//

import PDFKit
import SwiftUI

/// Shows a PDF held in memory. The bytes never touch the disk: `PDFDocument` reads them directly, which is why this
/// wraps PDFKit's view instead of handing a file to Quick Look.
struct PDFDocumentView: UIViewRepresentable {
    let data: Data

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.backgroundColor = .clear
        view.document = PDFDocument(data: data)
        return view
    }

    func updateUIView(_ view: PDFView, context: Context) {
        if view.document?.dataRepresentation() != data {
            view.document = PDFDocument(data: data)
        }
    }
}
