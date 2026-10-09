//
//  ExportContents.swift
//  BelloHub
//

import Foundation

/// What goes into the export (7.8): everything is always in; the photos are her choice because they make the file
/// large. The prototype's format and delivery choices are gone with D18 (one ZIP, saved to Files or shared).
struct ExportContents: Equatable, Sendable {
    var includesPhotos = false
}
