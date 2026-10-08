//
//  MotionArrivalModifier.swift
//  BelloHub
//

import SwiftUI

/// Staggered rise: opacity 0 to 1 and 14 pt up, once per screen presentation. `@State` lives as long
/// as the view does in its navigation stack, so popping back or switching tabs does not replay it.
/// The decisions are in `MotionArrival`, which is tested.
private struct MotionArrivalModifier: ViewModifier {
    let index: Int
    @Environment(\.motionPolicy) private var policy
    @State private var shown = false

    func body(content: Content) -> some View {
        let frame = MotionArrival.frame(shown: shown, policy: policy)
        content
            .opacity(frame.opacity)
            .offset(y: frame.offsetY)
            .onAppear {
                guard !shown else { return }
                if let animation = MotionArrival.animation(index: index, policy: policy) {
                    withAnimation(animation) { shown = true }
                } else {
                    shown = true
                }
            }
    }
}

extension View {
    /// Arrival animation for the block at `index` among a screen's top-level blocks. Prefer
    /// `StaggeredStack`, which assigns the indices.
    func motionArrival(index: Int) -> some View {
        modifier(MotionArrivalModifier(index: index))
    }
}
