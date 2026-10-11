//
//  FlowPhoto.swift
//  BelloHub
//

import Foundation

/// A photo added during the flow: its metadata as saved and its processed bytes, kept in memory so the screen can show
/// it and a change of visibility can save it again without reading the vault.
struct FlowPhoto: Identifiable, Equatable, Sendable {
    var photo: Photo
    let data: PhotoData

    var id: UUID { photo.id }
}
