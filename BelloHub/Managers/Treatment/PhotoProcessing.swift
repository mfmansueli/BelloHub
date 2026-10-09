//
//  PhotoProcessing.swift
//  BelloHub
//

import Foundation

/// Turns the bytes of a photo she took or picked into what the vault stores (docs/05-DATA-MODEL.md, "Photos pipeline"):
/// the longest side at most 2048 px, around 400 KB, no metadata (above all no location), plus a 320 px thumbnail.
/// The technology sits behind this protocol (D53) so the owner can swap the default (`ImageIOPhotoProcessing`) after v1.
/// The input never touches the photo library and the output is never written to it: the bytes go straight to
/// `TreatmentRepository.save(_:data:)`, which seals them.
protocol PhotoProcessing: Sendable {
    func process(_ source: Data) async throws -> PhotoData
}

/// Why a photo could not be prepared. The screen says "this picture could not be used" and lets her choose another.
enum PhotoProcessingError: Error, Equatable {
    /// The bytes are not an image the system can decode.
    case unreadable
    /// The image could not be re-encoded.
    case encodingFailed
}
