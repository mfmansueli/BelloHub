//
//  PhotoData.swift
//  BelloHub
//

import Foundation

/// The bytes of a photo after the pipeline: longest side at most 2048 px, around 400 KB, EXIF stripped,
/// plus a 320 px thumbnail. Decrypted only in memory.
struct PhotoData: Equatable, Sendable {
    var image: Data
    var thumbnail: Data
}
