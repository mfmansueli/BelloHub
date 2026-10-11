//
//  Motion.swift
//  BelloHub
//

import SwiftUI

/// The single motion language (decision D20, docs/09-MOTION.md). Nothing in `Screens/` invents an
/// animation: it uses the helpers in `DesignSystem/Motion/`, which use these tokens.
enum Motion {
    /// Ease-out quint, `cubic-bezier(0.22, 1, 0.36, 1)`: fast start, long soft landing.
    static func ease(_ duration: Double = Duration.rise) -> Animation {
        .timingCurve(0.22, 1.0, 0.36, 1.0, duration: duration)
    }

    /// One soft overshoot, `cubic-bezier(0.30, 1.25, 0.50, 1)`, only for the success circle.
    static func soft(_ duration: Double = Duration.pop) -> Animation {
        .timingCurve(0.30, 1.25, 0.50, 1.0, duration: duration)
    }

    enum Duration {
        static let press = 0.24
        static let fade = 0.28
        static let rise = 0.56
        static let sheet = 0.46
        static let pop = 0.62
        static let ring = 1.1
        static let draw = 0.5
        static let sheen = 1.5
        static let glow = 14.0
        static let pulse = 2.6
        static let bar = 0.5
        /// A value or a row that changes in place (docs/09-MOTION.md section 3.10, added 2026-10-12).
        static let change = 0.3
        /// The longest a change takes with Reduce Motion: a crossfade, never a movement.
        static let reducedFade = 0.2
        /// The white flash when a photo is taken.
        static let flash = 0.12
    }

    /// How far a block travels while it fades in.
    static let riseOffset: CGFloat = 14
    /// Seconds between siblings, for the first nine.
    static let stagger = 0.04
    /// Number of siblings that get a stagger; every one after them shares the last delay.
    static let staggeredCount = 9
    static let lateDelay = 0.36
    /// The bottom action bar rises last.
    static let barDelay = 0.18
    static let pressScale: CGFloat = 0.97
    static let pressScaleRow: CGFloat = 0.985
    /// How far the content of a new day travels while it slides in (the direction of travel; mirrors in Arabic).
    static let slideOffset: CGFloat = 24
    /// Peak opacity of the white capture flash.
    static let flashOpacity = 0.2

    /// Delay for the block at `index` of a screen's top-level blocks.
    static func arrivalDelay(index: Int) -> Double {
        index < staggeredCount ? Double(max(index, 0)) * stagger : lateDelay
    }
}
