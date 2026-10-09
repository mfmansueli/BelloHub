//
//  CameraPreview.swift
//  BelloHub
//

import SwiftUI
import UIKit

/// Hosts the live preview a `CameraCapturing` provides. UIKit only here, because SwiftUI has no preview layer of its own.
struct CameraPreview: UIViewRepresentable {
    let camera: any CameraCapturing

    func makeUIView(context: Context) -> UIView { camera.makePreviewView() }

    func updateUIView(_ uiView: UIView, context: Context) {}
}
