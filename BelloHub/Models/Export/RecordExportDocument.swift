//
//  RecordExportDocument.swift
//  BelloHub
//

import Foundation

/// A client record laid out as plain pieces of text and pictures, ready for any renderer: the words are already in her
/// language and nothing here is private beyond what she chose to include. A `RecordExporting` implementation draws it
/// (the default makes a PDF; the owner can replace it without touching the screens).
struct RecordExportDocument: Equatable, Sendable {
    enum Item: Equatable, Sendable {
        /// A short label and its value ("Allergies", "Latex").
        case line(label: String, value: String)
        /// A paragraph.
        case text(String)
        /// A picture with its caption. `image` is the processed JPEG the vault holds, decrypted in memory only.
        case photo(image: Data, caption: String)
    }

    struct Section: Equatable, Sendable {
        var heading: String
        var items: [Item]
    }

    var title: String
    var subtitle: String
    /// A file name that ends in `.pdf`.
    var fileName: String
    var sections: [Section]
    var footer: String
}
