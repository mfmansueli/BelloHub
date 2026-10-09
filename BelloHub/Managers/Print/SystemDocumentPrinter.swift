//
//  SystemDocumentPrinter.swift
//  BelloHub
//

import UIKit

/// `UIPrintInteractionController` as `DocumentPrinting` (docs/06-PRIVACY-SECURITY.md section 4.2: "Print" uses the
/// system sheet). The text goes to the printer only; nothing is kept.
@MainActor
final class SystemDocumentPrinter: DocumentPrinting {
    func print(text: String, jobName: String) {
        let info = UIPrintInfo(dictionary: nil)
        info.jobName = jobName
        info.outputType = .grayscale
        let controller = UIPrintInteractionController.shared
        controller.printInfo = info
        let formatter = UISimpleTextPrintFormatter(text: text)
        formatter.perPageContentInsets = UIEdgeInsets(top: 72, left: 72, bottom: 72, right: 72)
        controller.printFormatter = formatter
        controller.present(animated: true)
    }
}
