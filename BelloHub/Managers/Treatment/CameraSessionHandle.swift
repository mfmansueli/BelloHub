//
//  CameraSessionHandle.swift
//  BelloHub
//

import AVFoundation
import UIKit

/// The `AVCaptureSession` and everything that must not depend on the main actor (CLAUDE.md, Concurrency): starting
/// and stopping a session blocks, so it runs on this handle's own serial queue. `@unchecked Sendable` because every
/// access to the session and the output goes through `queue`, which is the thread discipline Apple documents for
/// `AVCaptureSession`; the handle owns them and nothing else keeps a reference.
final class CameraSessionHandle: @unchecked Sendable {
    private let queue = DispatchQueue(label: "app.bellohub.camera")
    private let session = AVCaptureSession()
    private let output = AVCapturePhotoOutput()
    private var isConfigured = false
    private var delegates: [Int64: PhotoDelegate] = [:]

    var hasCamera: Bool { Self.device != nil }
    var supportsFlash: Bool { Self.device?.hasFlash ?? false }

    private static var device: AVCaptureDevice? {
        AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
    }

    func start() async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            queue.async {
                self.configureIfNeeded()
                if self.isConfigured, !self.session.isRunning { self.session.startRunning() }
                continuation.resume()
            }
        }
    }

    func stop() {
        queue.async {
            if self.session.isRunning { self.session.stopRunning() }
        }
    }

    func capture(flashOn: Bool) async throws -> Data {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Data, Error>) in
            queue.async {
                guard self.isConfigured, self.session.isRunning else {
                    continuation.resume(throwing: CameraCaptureError.unavailable)
                    return
                }
                let settings = AVCapturePhotoSettings()
                if self.output.supportedFlashModes.contains(flashOn ? .on : .off) {
                    settings.flashMode = flashOn ? .on : .off
                }
                let delegate = PhotoDelegate { [weak self] result in
                    self?.queue.async { self?.delegates[settings.uniqueID] = nil }
                    continuation.resume(with: result)
                }
                self.delegates[settings.uniqueID] = delegate
                self.output.capturePhoto(with: settings, delegate: delegate)
            }
        }
    }

    /// The layer's session is set here so the preview shows what the handle runs.
    func attach(to layer: AVCaptureVideoPreviewLayer) {
        layer.session = session
    }

    // MARK: - Private

    private func configureIfNeeded() {
        guard !isConfigured, let device = Self.device,
              let input = try? AVCaptureDeviceInput(device: device) else { return }
        session.beginConfiguration()
        session.sessionPreset = .photo
        if session.canAddInput(input), session.canAddOutput(output) {
            session.addInput(input)
            session.addOutput(output)
            isConfigured = true
        }
        session.commitConfiguration()
    }
}

/// Collects one photo's bytes and hands them back. It is retained by the handle until the callback arrives.
private final class PhotoDelegate: NSObject, AVCapturePhotoCaptureDelegate, @unchecked Sendable {
    private let completion: @Sendable (Result<Data, Error>) -> Void

    init(completion: @escaping @Sendable (Result<Data, Error>) -> Void) {
        self.completion = completion
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let data = photo.fileDataRepresentation(), error == nil {
            completion(.success(data))
        } else {
            completion(.failure(CameraCaptureError.failed))
        }
    }
}
