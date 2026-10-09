//
//  AVCameraCapture.swift
//  BelloHub
//

import AVFoundation
import UIKit

/// The real camera: a back-camera `AVCaptureSession` with a photo output. It only ever returns bytes; nothing here
/// touches `PHPhotoLibrary`, so a shot cannot reach the camera roll.
@MainActor
final class AVCameraCapture: CameraCapturing {
    private let handle = CameraSessionHandle()
    private var flashOn = false

    var hasCamera: Bool { handle.hasCamera }
    var supportsFlash: Bool { handle.supportsFlash }

    func start() async { await handle.start() }

    func stop() { handle.stop() }

    func setFlash(_ isOn: Bool) { flashOn = isOn }

    func capture() async throws -> Data { try await handle.capture(flashOn: flashOn) }

    func makePreviewView() -> UIView {
        let view = CameraPreviewUIView()
        view.previewLayer.videoGravity = .resizeAspectFill
        handle.attach(to: view.previewLayer)
        return view
    }
}

/// A view that shows the live preview in a sublayer that follows its bounds.
private final class CameraPreviewUIView: UIView {
    let previewLayer = AVCaptureVideoPreviewLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        layer.addSublayer(previewLayer)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        layer.addSublayer(previewLayer)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer.frame = bounds
    }
}
