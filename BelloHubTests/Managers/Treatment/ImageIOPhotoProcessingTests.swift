//
//  ImageIOPhotoProcessingTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import ImageIO
import Testing
import UIKit

@Suite("ImageIOPhotoProcessing")
struct ImageIOPhotoProcessingTests {
    /// A JPEG with EXIF (a camera model, a user comment) and GPS coordinates, which must not survive.
    private func makeSource(width: Int, height: Int) throws -> Data {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format)
        let image = renderer.image { context in
            UIColor.systemPink.setFill()
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }
        let data = NSMutableData()
        let destination = try #require(CGImageDestinationCreateWithData(data, "public.jpeg" as CFString, 1, nil))
        let properties: [CFString: Any] = [
            kCGImagePropertyExifDictionary: [kCGImagePropertyExifUserComment: "private note"],
            kCGImagePropertyGPSDictionary: [
                kCGImagePropertyGPSLatitude: 51.5, kCGImagePropertyGPSLatitudeRef: "N",
                kCGImagePropertyGPSLongitude: 0.12, kCGImagePropertyGPSLongitudeRef: "E"
            ],
            kCGImagePropertyTIFFDictionary: [kCGImagePropertyTIFFModel: "iPhone"]
        ]
        CGImageDestinationAddImage(destination, try #require(image.cgImage), properties as CFDictionary)
        #expect(CGImageDestinationFinalize(destination))
        return data as Data
    }

    private func properties(of data: Data) throws -> [CFString: Any] {
        let source = try #require(CGImageSourceCreateWithData(data as CFData, nil))
        return try #require(CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any])
    }

    private func longestSide(of data: Data) throws -> Int {
        let found = try properties(of: data)
        return max(found[kCGImagePropertyPixelWidth] as? Int ?? 0, found[kCGImagePropertyPixelHeight] as? Int ?? 0)
    }

    @Test("A large photo is scaled to 2048 px on its longest side, with a 320 px thumbnail")
    func scalesDown() async throws {
        let source = try makeSource(width: 3000, height: 4000)
        let result = try await ImageIOPhotoProcessing().process(source)
        #expect(try longestSide(of: result.image) == 2048)
        #expect(try longestSide(of: result.thumbnail) == 320)
    }

    @Test("A small photo is never scaled up")
    func neverScalesUp() async throws {
        let source = try makeSource(width: 200, height: 100)
        let result = try await ImageIOPhotoProcessing().process(source)
        #expect(try longestSide(of: result.image) == 200)
        #expect(try longestSide(of: result.thumbnail) == 200)
    }

    @Test("EXIF, GPS and TIFF metadata of the source do not survive, in the image or in the thumbnail")
    func removesMetadata() async throws {
        let source = try makeSource(width: 600, height: 800)
        let sourceProperties = try properties(of: source)
        #expect(sourceProperties[kCGImagePropertyGPSDictionary] != nil, "the test source carries GPS")
        let result = try await ImageIOPhotoProcessing().process(source)
        for data in [result.image, result.thumbnail] {
            let found = try properties(of: data)
            #expect(found[kCGImagePropertyGPSDictionary] == nil)
            let exif = found[kCGImagePropertyExifDictionary] as? [CFString: Any]
            #expect(exif?[kCGImagePropertyExifUserComment] == nil)
            let tiff = found[kCGImagePropertyTIFFDictionary] as? [CFString: Any]
            #expect(tiff?[kCGImagePropertyTIFFModel] == nil)
        }
    }

    @Test("Bytes that are not an image are refused")
    func refusesGarbage() async {
        await #expect(throws: PhotoProcessingError.unreadable) {
            _ = try await ImageIOPhotoProcessing().process(Data("not an image".utf8))
        }
    }
}
