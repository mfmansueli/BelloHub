//
//  MotionSettleModifier.swift
//  BelloHub
//

import SwiftUI

private struct MotionSettleModifier<Value: Equatable>: ViewModifier {
    let value: Value
    @Environment(\.motionPolicy) private var policy

    func body(content: Content) -> some View {
        content.animation(MotionChange.animation(.settle, policy: policy), value: value)
    }
}

extension View {
    /// A block that changes place (a visit moved to another time, the "now" line, a progress bar) glides to it with
    /// `ease(0.3)`; with Reduce Motion it is simply there. `value` is whatever decides the place.
    func motionSettle(_ value: some Equatable) -> some View {
        modifier(MotionSettleModifier(value: value))
    }
}
