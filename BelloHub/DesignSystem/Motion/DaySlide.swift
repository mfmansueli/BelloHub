//
//  DaySlide.swift
//  BelloHub
//

import SwiftUI

/// Switching day or week slides the columns in the direction of travel (docs/09-MOTION.md section 3.10, added
/// 2026-10-12): going later brings the new content in from the trailing edge, going earlier from the leading edge, and
/// both flip in Arabic because the offset goes through `Directional`. Pure, so the direction is tested for both
/// reading directions.
enum DaySlide {
    enum Travel: Equatable, Sendable {
        case forward
        case backward
        /// The same place (a mode switch, a first appearance): a crossfade, no travel.
        case none
    }

    static func travel(from old: Date, to new: Date) -> Travel {
        if new > old { return .forward }
        return new < old ? .backward : .none
    }

    /// Where the arriving content starts, in points to the right of its place (negative is to the left). With Reduce
    /// Motion and in UI tests it starts in place.
    static func startOffset(_ travel: Travel, layoutDirection: LayoutDirection, policy: MotionPolicy) -> CGFloat {
        guard policy.allowsMovement else { return 0 }
        switch travel {
        case .forward: return Directional.x(Motion.slideOffset, layoutDirection: layoutDirection)
        case .backward: return Directional.x(-Motion.slideOffset, layoutDirection: layoutDirection)
        case .none: return 0
        }
    }
}

private struct SlideInModifier: ViewModifier {
    let offset: CGFloat
    let opacity: Double

    func body(content: Content) -> some View {
        content.offset(x: offset).opacity(opacity)
    }
}

private struct DaySlideModifier: ViewModifier {
    let travel: DaySlide.Travel
    @Environment(\.motionPolicy) private var policy
    @Environment(\.layoutDirection) private var layoutDirection

    func body(content: Content) -> some View {
        content.transition(transition)
    }

    /// The arriving content starts displaced and transparent; the old one only fades, because a removal reads the
    /// transition it had before the change, so its direction could be stale.
    private var transition: AnyTransition {
        guard policy.allowsFade else { return .identity }
        let offset = DaySlide.startOffset(travel, layoutDirection: layoutDirection, policy: policy)
        return .asymmetric(
            insertion: .modifier(
                active: SlideInModifier(offset: offset, opacity: 0), identity: SlideInModifier(offset: 0, opacity: 1)
            ),
            removal: .opacity
        )
    }
}

extension View {
    /// The transition of a day or week's content, keyed with `.id` on what it shows. Pair it with an animation on
    /// the same key.
    func motionDaySlide(travel: DaySlide.Travel) -> some View {
        modifier(DaySlideModifier(travel: travel))
    }
}
