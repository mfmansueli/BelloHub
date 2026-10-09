//
//  ExportedFile.swift
//  BelloHub
//

import Foundation

/// A file an export wrote, waiting to be shared and then deleted.
struct ExportedFile: Equatable, Sendable {
    let url: URL

    var fileName: String { url.lastPathComponent }
}
