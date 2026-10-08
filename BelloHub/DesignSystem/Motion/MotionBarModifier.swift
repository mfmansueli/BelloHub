//
//  MotionBarModifier.swift
//  BelloHub
//

import SwiftUI

/// The sticky bottom action area rises last: opacity and 14 pt, 0.5 s, after a 0.18 s delay.
private struct MotionBarModifier: ViewModifier {
    @Environment(\.motionPolicy) private var policy
    @State private var shown = false

    func body(content: Content) -> some View {
        content
            .opacity(shown || !policy.allowsFade ? 1 : 0)
            .offset(y: shown || !policy.allowsMovement ? 0 : Motion.riseOffset)
            .onAppear {
                guard !shown else { return }
                if policy.allowsFade {
                    withAnimation(Motion.ease(Motion.Duration.bar).delay(Motion.barDelay)) { shown = true }
                } else {
                    shown = true
                }
            }
    }
}

extension View {
    /// Apply to the content of `safeAreaInset(edge: .bottom)`.
    func motionBar() -> some View {
        modifier(MotionBarModifier())
    }
}
