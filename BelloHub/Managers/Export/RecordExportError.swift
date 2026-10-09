//
//  RecordExportError.swift
//  BelloHub
//

import Foundation

enum RecordExportError: Error, Equatable {
    /// The renderer produced no pages.
    case nothingToDraw
    /// The file could not be written.
    case cannotWrite
}
