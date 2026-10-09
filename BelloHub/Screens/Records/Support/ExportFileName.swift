//
//  ExportFileName.swift
//  BelloHub
//

import Foundation

/// The name of the exported file: "Ana-Costa-record.pdf". It is safe in any file system and carries no more of the
/// client's name than the first letters and digits of each word.
enum ExportFileName {
    static func make(clientName: String, suffix: String) -> String {
        let folded = clientName.folding(options: [.diacriticInsensitive], locale: nil)
        let words = folded
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
        let base = (words + [suffix]).joined(separator: "-")
        return base + ".pdf"
    }
}
