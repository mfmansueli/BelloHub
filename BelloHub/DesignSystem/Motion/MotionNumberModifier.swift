//
//  MotionNumberModifier.swift
//  BelloHub
//

import SwiftUI

/// A number or a time that flows to its new value instead of jumping (docs/09-MOTION.md section 3.10). It animates
/// only when `value` changes: the first text a view shows is never animated from zero (the arrival handles that), and
/// a value that did not change stays still. The decisions are `MotionChange`'s.
private struct MotionNumberModifier<Value: Equatable>: ViewModifier {
    let value: Value
    let countsDown: Bool
    @Environment(\.motionPolicy) private var policy

    func body(content: Content) -> some View {
        content
            .contentTransition(transition)
            .animation(MotionChange.animation(.number, policy: policy), value: value)
    }

    private var transition: ContentTransition {
        switch MotionChange.numberStyle(policy: policy) {
        case .rolling: .numericText(countsDown: countsDown)
        case .crossfade: .opacity
        case .instant: .identity
        }
    }
}

extension View {
    /// Apply to the `Text` that shows a count, a time, a duration or a total, with the value (or the string) that
    /// drives it. `countsDown` is for a countdown ("in 1 h 20 min"), so the digits roll the other way.
    func motionNumber(_ value: some Equatable, countsDown: Bool = false) -> some View {
        modifier(MotionNumberModifier(value: value, countsDown: countsDown))
    }
}
