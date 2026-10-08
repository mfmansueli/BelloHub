//
//  Photo.swift
//  BelloHub
//

import Foundation

/// A photo's metadata. The image and thumbnail bytes are encrypted and kept apart (`PhotoData`).
struct Photo: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    var clientID: UUID
    var recordID: UUID?
    var takenAt: Date
    var kind: PhotoKind
    var visibility: PhotoVisibility
}
