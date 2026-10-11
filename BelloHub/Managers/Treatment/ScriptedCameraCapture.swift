//
//  ScriptedCameraCapture.swift
//  BelloHub
//

#if DEBUG
import UIKit

/// `-uiCamera scripted`: a camera that "takes" a generated picture, because a simulator has none. The preview is a
/// plain colored view. DEBUG only; it never ships.
@MainActor
final class ScriptedCameraCapture: CameraCapturing {
    let hasCamera = true
    let supportsFlash = true

    func start() async {}

    func stop() {}

    func setFlash(_ isOn: Bool) {}

    func capture() async throws -> Data {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 1200, height: 1600))
        return renderer.jpegData(withCompressionQuality: 0.9) { context in
            UIColor(red: 0.85, green: 0.72, blue: 0.68, alpha: 1).setFill()
            context.fill(CGRect(x: 0, y: 0, width: 1200, height: 1600))
            UIColor(red: 0.6, green: 0.35, blue: 0.42, alpha: 1).setFill()
            context.cgContext.fillEllipse(in: CGRect(x: 300, y: 400, width: 600, height: 800))
        }
    }

    func makePreviewView() -> UIView {
        let view = UIView()
        view.backgroundColor = UIColor(red: 0.2, green: 0.19, blue: 0.18, alpha: 1)
        return view
    }
}
#endif
