//
//  FakePhotoProcessing.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation

/// Photo processing that returns the source as both sizes, or throws.
struct FakePhotoProcessing: PhotoProcessing {
    var fails = false

    func process(_ source: Data) async throws -> PhotoData {
        if fails { throw PhotoProcessingError.unreadable }
        return PhotoData(image: source, thumbnail: source)
    }
}
