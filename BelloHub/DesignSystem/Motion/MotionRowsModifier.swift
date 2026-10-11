//
//  MotionRowsModifier.swift
//  BelloHub
//

import SwiftUI

/// Animates only the identities that were inserted or removed, and the rows that close or open the gap
/// (docs/09-MOTION.md section 3.10). It never animates a load: while the list is not ready, for the first list it
/// sees, when the context (the day, the filter) changes, or when more than a few rows change at once, nothing moves.
/// Put it on the container, and `motionRow()` on each row.
private struct MotionRowsModifier<ID: Hashable>: ViewModifier {
    let ids: [ID]
    let context: AnyHashable
    let isReady: Bool
    @Environment(\.motionPolicy) private var policy
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver
    @State private var settled: MotionChange.RowSnapshot<ID>?

    func body(content: Content) -> some View {
        let current = MotionChange.RowSnapshot(ids: ids, context: context)
        content
            .animation(
                MotionChange.rowsAnimation(before: settled, after: current, isReady: isReady, policy: policy),
                value: ids
            )
            .onChange(of: current, initial: true) { _, new in settle(new) }
            .onChange(of: isReady) { settle(current) }
    }

    private func settle(_ new: MotionChange.RowSnapshot<ID>) {
        guard isReady else {
            settled = nil
            return
        }
        if let settled, settled.context == new.context {
            let change = MotionChange.rowChange(from: settled.ids, to: new.ids)
            // A removed row leaves VoiceOver's focus on nothing: tell it the screen changed so it lands on a row
            // that exists.
            if MotionChange.postsLayoutChange(change, voiceOver: voiceOver) {
                AccessibilityNotification.LayoutChanged().post()
            }
        }
        settled = new
    }
}

private struct MotionRowModifier: ViewModifier {
    @Environment(\.motionPolicy) private var policy

    func body(content: Content) -> some View {
        content.transition(MotionChange.rowTransition(policy: policy))
    }
}

extension View {
    /// On the container of a list of rows: the identities in order, the context they belong to (a different one is a
    /// different list, so nothing animates) and whether the data has loaded.
    func motionRows(ids: [some Hashable], context: some Hashable = 0, isReady: Bool = true) -> some View {
        modifier(MotionRowsModifier(ids: ids, context: AnyHashable(context), isReady: isReady))
    }

    /// On each row: enters from above with a fade, leaves with a fade and a slide (a fade with Reduce Motion).
    func motionRow() -> some View {
        modifier(MotionRowModifier())
    }
}
