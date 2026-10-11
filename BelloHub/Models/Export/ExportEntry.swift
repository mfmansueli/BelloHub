//
//  ExportEntry.swift
//  BelloHub
//

import Foundation

/// One file of the export archive: its path inside the ZIP and its bytes.
struct ExportEntry: Equatable, Sendable {
    let name: String
    let data: Data
}
