//
//  Skeleton.swift
//  BelloHub
//

import SwiftUI

/// A loading placeholder in the shape of the content it stands for. It pulses gently, and stays still
/// with Reduce Motion or Low Power Mode. Cross-fades to the real content (0.28 s) when the data arrives.
struct Skeleton: View {
    var height: CGFloat = 16
    var cornerRadius: CGFloat = Radius.control
    @Environment(\.motionPolicy) private var policy

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Palette.sunken)
            .frame(height: height)
            .phaseAnimator(policy.allowsAmbient ? [1.0, 0.55] : [1.0]) { view, opacity in
                view.opacity(opacity)
            } animation: { _ in
                .easeInOut(duration: 0.9)
            }
            .accessibilityHidden(true)
    }
}
