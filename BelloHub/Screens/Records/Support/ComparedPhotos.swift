//
//  ComparedPhotos.swift
//  BelloHub
//

import Foundation

/// Two photos she picked to compare, oldest first, as a sheet item.
struct ComparedPhotos: Identifiable, Hashable, Sendable {
    let first: Photo
    let second: Photo

    var id: String { "\(first.id.uuidString).\(second.id.uuidString)" }
}
