//
//  PhotoMemoryCacheTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

/// docs/13 section 6 (memory with 200 photos): thumbnails stay, full-size images only for the last few.
@Suite("PhotoMemoryCache")
struct PhotoMemoryCacheTests {
    private func data(_ number: Int) -> PhotoData {
        PhotoData(image: Data(repeating: UInt8(number % 256), count: 1_000), thumbnail: Data([UInt8(number % 256)]))
    }

    @Test("Scrolling 200 photos keeps 200 thumbnails and only the last few full-size images")
    func bounded() {
        var cache = PhotoMemoryCache()
        let ids = (0..<200).map { _ in UUID() }
        for (index, id) in ids.enumerated() { cache.store(data(index), for: id) }

        #expect(cache.thumbnails.count == 200)
        #expect(cache.fullSize.count == PhotoMemoryCache.fullSizeLimit)
        #expect(cache.photo(ids[199]) == data(199))
        #expect(cache.photo(ids[0]) == nil, "an old full-size image is decrypted again when opened")
        #expect(cache.thumbnail(ids[0]) == data(0).thumbnail)
    }

    @Test("Opening a photo again makes it the most recent")
    func recency() {
        var cache = PhotoMemoryCache()
        let ids = (0..<5).map { _ in UUID() }
        for (index, id) in ids.prefix(4).enumerated() { cache.store(data(index), for: id) }
        cache.store(data(0), for: ids[0])
        cache.store(data(4), for: ids[4])

        #expect(cache.photo(ids[0]) != nil, "the re-opened photo stays")
        #expect(cache.photo(ids[1]) == nil, "the least recent goes")
        #expect(cache.fullSize.last == ids[4])
    }
}
