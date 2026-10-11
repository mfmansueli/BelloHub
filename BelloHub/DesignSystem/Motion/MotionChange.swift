//
//  MotionChange.swift
//  BelloHub
//

import SwiftUI

/// What moves when something changes in place (docs/09-MOTION.md section 3.10, added 2026-10-12): a number or a time,
/// a row that enters or leaves, a block that settles on a new slot. Pure, so the decisions are tested without a view.
/// The modifiers (`motionNumber`, `motionRows`, `motionRow`, `motionSettle`) only read these answers; no screen
/// picks its own animation.
enum MotionChange {
    enum Kind: Equatable {
        /// A numeral or a time that changes its digits.
        case number
        /// A row that is inserted or removed, and the rows that close the gap.
        case rows
        /// A block that moves to its new place.
        case settle
        /// A short fade, for an element that appears or goes.
        case fade
        /// The content of a day or a week that slides in the direction of travel.
        case slide
    }

    /// The animation for a change of `kind`, or nil when nothing should animate: `-uiTesting` is instant; Reduce
    /// Motion keeps a crossfade of at most 0.2 s and never a movement.
    static func animation(_ kind: Kind, policy: MotionPolicy) -> Animation? {
        guard policy.allowsFade else { return nil }
        guard policy.allowsMovement else {
            // A block that changes place has nothing to crossfade: with Reduce Motion it is simply there.
            return kind == .settle ? nil : .easeOut(duration: Motion.Duration.reducedFade)
        }
        switch kind {
        case .number, .rows, .settle, .slide: return Motion.ease(Motion.Duration.change)
        case .fade: return Motion.ease(Motion.Duration.fade)
        }
    }

    // MARK: - Numbers

    enum NumberStyle: Equatable {
        /// The digits roll (`numericText`).
        case rolling
        /// Reduce Motion: the new text fades in over the old one.
        case crossfade
        /// UI testing: it changes at once.
        case instant
    }

    static func numberStyle(policy: MotionPolicy) -> NumberStyle {
        if !policy.allowsFade { return .instant }
        return policy.allowsMovement ? .rolling : .crossfade
    }

    /// Whether a value change plays at all: the first value a view ever shows is its arrival's business, and a value
    /// that did not change stays still.
    static func animatesValue<Value: Equatable>(from old: Value?, to new: Value, policy: MotionPolicy) -> Bool {
        guard let old, old != new else { return false }
        return policy.allowsFade
    }

    // MARK: - Rows

    /// How many identities came and went between two lists.
    struct RowChange: Equatable {
        let inserted: Int
        let removed: Int
        /// The same identities in another order.
        let isReorder: Bool

        var isNone: Bool { inserted == 0 && removed == 0 && !isReorder }
    }

    /// A person adds, removes or moves a few rows at a time. A load, a sync or an import changes dozens at once,
    /// and animating those would be noise and, in a list of thousands, a stall.
    static let maxAnimatedRowChanges = 12
    /// A reorder alone animates only in a short list; moving hundreds of rows is not a thing she needs to watch.
    static let maxAnimatedReorderCount = 60

    static func rowChange<ID: Hashable>(from old: [ID], to new: [ID]) -> RowChange {
        let oldSet = Set(old)
        let newSet = Set(new)
        let inserted = newSet.subtracting(oldSet).count
        let removed = oldSet.subtracting(newSet).count
        let isReorder = inserted == 0 && removed == 0 && old != new
        return RowChange(inserted: inserted, removed: removed, isReorder: isReorder)
    }

    /// What a list looked like when it last settled: its identities and the context they belong to (the day, the
    /// filter). A different context is a different list, not a change in this one.
    struct RowSnapshot<ID: Hashable>: Equatable {
        var ids: [ID]
        var context: AnyHashable = 0
    }

    /// The animation for a list that went from `before` to `after`. Nil when the list was not ready (loading), when
    /// it is the first one the view has seen, when the context changed, or when too much changed at once.
    static func rowsAnimation<ID: Hashable>(
        before: RowSnapshot<ID>?, after: RowSnapshot<ID>, isReady: Bool, policy: MotionPolicy
    ) -> Animation? {
        guard isReady, let before, before.context == after.context else { return nil }
        let change = rowChange(from: before.ids, to: after.ids)
        let count = change.inserted + change.removed
        let fits = count > 0 ? count <= maxAnimatedRowChanges
            : change.isReorder && after.ids.count <= maxAnimatedReorderCount
        guard fits else { return nil }
        return animation(.rows, policy: policy)
    }

    enum RowStyle: Equatable {
        /// Enters from above with a fade, leaves with a fade and a slide up.
        case slideAndFade
        /// Reduce Motion: a fade only.
        case fade
        case none
    }

    static func rowStyle(policy: MotionPolicy) -> RowStyle {
        if !policy.allowsFade { return .none }
        return policy.allowsMovement ? .slideAndFade : .fade
    }

    static func rowTransition(policy: MotionPolicy) -> AnyTransition {
        switch rowStyle(policy: policy) {
        case .slideAndFade: .opacity.combined(with: .move(edge: .top))
        case .fade: .opacity
        case .none: .identity
        }
    }

    /// VoiceOver is told the screen changed when rows left, so its focus does not stay on a row that is gone.
    static func postsLayoutChange(_ change: RowChange, voiceOver: Bool) -> Bool {
        voiceOver && change.removed > 0
    }
}
