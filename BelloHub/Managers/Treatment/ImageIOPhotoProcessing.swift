//
//  ImageIOPhotoProcessing.swift
//  BelloHub
//

import Foundation
import ImageIO
import UniformTypeIdentifiers

/// The default photo pipeline, on ImageIO only: it decodes the source once per output, scales it down (never up),
/// applies the orientation to the pixels, and re-encodes as JPEG from the bare pixels, so no EXIF, GPS, TIFF or
/// maker note from the source can survive. It does not use the photo library in any way.
struct ImageIOPhotoProcessing: PhotoProcessing {
    static let maximumSide = 2048
    static let thumbnailSide = 320
    /// The size the full image aims for; quality steps down until it fits, so a detailed photo is not rejected.
    static let targetBytes = 400_000

    func process(_ source: Data) async throws -> PhotoData {
        try await Task.detached(priority: .userInitiated) { try Self.run(source) }.value
    }

    // MARK: - Private

    private static let qualities: [Double] = [0.85, 0.75, 0.65, 0.55, 0.45, 0.35]

    private static func run(_ source: Data) throws -> PhotoData {
        guard let imageSource = CGImageSourceCreateWithData(source as CFData, nil),
              CGImageSourceGetCount(imageSource) > 0 else { throw PhotoProcessingError.unreadable }
        let image = try encode(imageSource, side: maximumSide, qualities: qualities, targetBytes: targetBytes)
        let thumbnail = try encode(imageSource, side: thumbnailSide, qualities: [0.7], targetBytes: .max)
        return PhotoData(image: image, thumbnail: thumbnail)
    }

    private static func encode(_ source: CGImageSource, side: Int, qualities: [Double], targetBytes: Int) throws -> Data {
        guard let scaled = scaledImage(source, side: side) else { throw PhotoProcessingError.unreadable }
        var smallest: Data?
        for quality in qualities {
            guard let data = jpeg(scaled, quality: quality) else { throw PhotoProcessingError.encodingFailed }
            smallest = data
            if data.count <= targetBytes { break }
        }
        guard let result = smallest else { throw PhotoProcessingError.encodingFailed }
        return result
    }

    /// The image with its longest side at most `side` pixels, upright. `kCGImageSourceCreateThumbnailWithTransform`
    /// bakes the EXIF orientation into the pixels, so the orientation tag does not need to be written back.
    private static func scaledImage(_ source: CGImageSource, side: Int) -> CGImage? {
        let longest = longestSide(of: source) ?? side
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: min(side, longest)
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    private static func longestSide(of source: CGImageSource) -> Int? {
        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int else { return nil }
        return max(width, height)
    }

    /// JPEG bytes of the bare pixels: the destination is given no metadata, only the compression quality.
    private static func jpeg(_ image: CGImage, quality: Double) -> Data? {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil)
        else { return nil }
        let options: [CFString: Any] = [kCGImageDestinationLossyCompressionQuality: quality]
        CGImageDestinationAddImage(destination, image, options as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return data as Data
    }
}
