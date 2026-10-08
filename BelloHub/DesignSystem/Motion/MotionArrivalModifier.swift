//
//  MotionArrivalModifier.swift
//  BelloHub
//

import SwiftUI

/// Staggered rise: opacity 0 to 1 and 14 pt up, once per screen presentation. `@State` lives as long
/// as the view does in its navigation stack, so popping back or switching tabs does not replay it.
private struct MotionArrivalModifier: ViewModifier {
    let index: Int
    @Environment(\.motionPolicy) private var policy
    @State private var shown = false

    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .offset(y: isVisible || !policy.allowsMovement ? 0 : Motion.riseOffset)
            .onAppear {
                guard !shown else { return }
                if policy.allowsFade {
                    withAnimation(animation) { shown = true }
                } else {
                    shown = true
                }
            }
    }

    /// Without movement the content is still there at once; only the fade is kept (Reduce Motion).
    private var isVisible: Bool {
        shown || !policy.allowsMovement && !policy.allowsFade
    }

    private var animation: Animation {
        policy.allowsMovement
            ? Motion.ease().delay(Motion.arrivalDelay(index: index))
            : .easeOut(duration: 0.2)
    }
}

extension View {
    /// Arrival animation for the block at `index` among a screen's top-level blocks. Prefer
    /// `StaggeredStack`, which assigns the indices.
    func motionArrival(index: Int) -> some View {
        modifier(MotionArrivalModifier(index: index))
    }
}
