//
//  CameraCapturing.swift
//  BelloHub
//

import UIKit

/// The camera behind the Camera screen (5.8). The technology sits behind this protocol so the screen is tested with a
/// fake and the owner can refine the real capture later (D53). A shot comes back as bytes in memory: it is never
/// written to the camera roll (docs/05-DATA-MODEL.md, "Photos pipeline"), and the bytes go to `PhotoProcessing`.
@MainActor
protocol CameraCapturing: AnyObject {
    /// Whether this device has a camera it can use. A simulator does not: the screen then offers the photo library.
    var hasCamera: Bool { get }
    var supportsFlash: Bool { get }
    /// Starts the live preview. Call only once the camera permission is granted.
    func start() async
    func stop()
    func setFlash(_ isOn: Bool)
    /// Takes one photo and returns its bytes, in memory only.
    func capture() async throws -> Data
    /// The view that shows the live preview, for `CameraPreview`.
    func makePreviewView() -> UIView
}

/// Why a shot failed. The screen says "that photo did not work, try again".
enum CameraCaptureError: Error, Equatable {
    case unavailable
    case failed
}
