//
//  CaptureFlash.swift
//  BelloHub
//

import SwiftUI

/// The white flash when a photo is taken (docs/09-MOTION.md section 3.10): 20 % white that fades out over 0.12 s, with
/// a medium impact haptic. With Reduce Motion there is no flash (a flash is the kind of sudden change that setting
/// exists to remove) and the haptic stays; in UI tests nothing flashes. Pure, so it is tested without a view.
enum CaptureFlash {
    /// The brightest the flash gets, as the opacity of white over the picture.
    static func peakOpacity(policy: MotionPolicy) -> Double {
        policy.allowsMovement ? Motion.flashOpacity : 0
    }

    /// How long it takes to fade out.
    static func duration(policy: MotionPolicy) -> Double {
        Motion.Duration.flash
    }
}

private struct CaptureFlashModifier: ViewModifier {
    let trigger: Int
    @Environment(\.motionPolicy) private var policy
    @State private var opacity = 0.0

    func body(content: Content) -> some View {
        content
            .overlay {
                Color.white.opacity(opacity)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
            .sensoryFeedback(.impact(weight: .medium), trigger: trigger) { _, new in new > 0 }
            .onChange(of: trigger) { _, new in
                guard new > 0 else { return }
                let peak = CaptureFlash.peakOpacity(policy: policy)
                guard peak > 0 else { return }
                opacity = peak
                withAnimation(.easeOut(duration: CaptureFlash.duration(policy: policy))) { opacity = 0 }
            }
    }
}

extension View {
    /// Flashes white and taps the haptic each time `trigger` goes up (a photo was taken).
    func captureFlash(trigger: Int) -> some View {
        modifier(CaptureFlashModifier(trigger: trigger))
    }
}
