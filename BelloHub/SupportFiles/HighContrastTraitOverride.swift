//
//  HighContrastTraitOverride.swift
//  BelloHub
//

#if DEBUG
import SwiftUI
import UIKit

/// `-uiIncreaseContrast` (DEBUG): sets the window scene's `accessibilityContrast` trait to high once the app has a
/// window, so every dynamic `Palette` color resolves to its Increase Contrast pair, as with the setting on. SwiftUI's
/// `colorSchemeContrast` is read-only, hence a zero-size UIKit view. Test hook only; compiled out of Release.
struct HighContrastTraitOverride: UIViewRepresentable {
    func makeUIView(context: Context) -> OverrideView {
        OverrideView()
    }

    func updateUIView(_ uiView: OverrideView, context: Context) {}

    /// Applies the override when it joins a window.
    final class OverrideView: UIView {
        override func didMoveToWindow() {
            super.didMoveToWindow()
            window?.windowScene?.traitOverrides.accessibilityContrast = .high
        }
    }
}
#endif
