//
//  SummaryPDFRenderer.swift
//  BelloHub
//

import UIKit

/// The one-page summary PDF of the export, drawn with UIKit's PDF renderer on the device (D18: nothing leaves the
/// iPhone). System fonts, so every script the app ships renders.
struct SummaryPDFRenderer: Sendable {
    func render(_ summary: ExportBundleBuilder.Summary) -> Data {
        let page = CGRect(x: 0, y: 0, width: 595, height: 842) // A4 at 72 dpi
        let renderer = UIGraphicsPDFRenderer(bounds: page)
        return renderer.pdfData { context in
            context.beginPage()
            let margin: CGFloat = 48
            var cursor = margin
            let title = NSAttributedString(string: summary.title, attributes: [
                .font: UIFont.preferredFont(forTextStyle: .title1), .foregroundColor: UIColor.label
            ])
            title.draw(in: CGRect(x: margin, y: cursor, width: page.width - 2 * margin, height: 40))
            cursor += 56
            for line in summary.lines {
                let text = NSAttributedString(string: line, attributes: [
                    .font: UIFont.preferredFont(forTextStyle: .body), .foregroundColor: UIColor.label
                ])
                let bounds = text.boundingRect(
                    with: CGSize(width: page.width - 2 * margin, height: .greatestFiniteMagnitude),
                    options: [.usesLineFragmentOrigin], context: nil
                )
                text.draw(in: CGRect(x: margin, y: cursor, width: page.width - 2 * margin, height: bounds.height + 4))
                cursor += bounds.height + 14
            }
        }
    }
}
