//
//  PhotoMemoryCache.swift
//  BelloHub
//

import Foundation

/// What a screen keeps of a client's decrypted photos while it is open (docs/13-TESTING-QUALITY.md section 6: memory
/// with 200 photos ≤ 250 MB; thumbnails only in strips and grids, full size on demand). Every thumbnail stays (they are
/// small and a strip scrolls back and forth); full-size images are kept only for the few most recently opened, so
/// scrolling a timeline of 200 photos never holds 200 full-size images. Pure value type.
struct PhotoMemoryCache: Equatable, Sendable {
    /// Enough for a before/after pair and the photo opened on top of it.
    static let fullSizeLimit = 4

    private(set) var thumbnails: [UUID: Data] = [:]
    /// Most recent last.
    private(set) var fullSize: [UUID] = []
    private var images: [UUID: Data] = [:]

    /// The full photo when both halves are here.
    func photo(_ id: UUID) -> PhotoData? {
        guard let image = images[id], let thumbnail = thumbnails[id] else { return nil }
        return PhotoData(image: image, thumbnail: thumbnail)
    }

    func thumbnail(_ id: UUID) -> Data? {
        thumbnails[id]
    }

    /// Keeps the thumbnail, and the full image among the most recent ones.
    mutating func store(_ data: PhotoData, for id: UUID) {
        thumbnails[id] = data.thumbnail
        images[id] = data.image
        fullSize.removeAll { $0 == id }
        fullSize.append(id)
        while fullSize.count > Self.fullSizeLimit {
            images[fullSize.removeFirst()] = nil
        }
    }
}
