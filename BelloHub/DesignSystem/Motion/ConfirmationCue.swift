//
//  ConfirmationCue.swift
//  BelloHub
//

import Foundation

/// When a finished action is confirmed with a seal and a haptic, and for how long (docs/09-MOTION.md section 3.6 and
/// the 2026-10-12 additions). Pure, so the triggers are tested without a view. The confirmation is brief and never
/// blocks: the next action stays tappable at once.
enum ConfirmationCue {
    /// How long the brief seal stays before it fades: the pop (0.1 s delay, 0.62 s), the check, then a moment to read.
    static let sealHold = 1.5

    /// A count went up (a photo saved, a message marked as sent). A count that stays or goes down is not a
    /// confirmation, and neither is the first count the screen shows.
    static func fires(countFrom old: Int, to new: Int) -> Bool {
        new > old
    }

    /// A flag turned on (a request confirmed). Starting on is not a confirmation: she opened something already done.
    static func fires(flagFrom old: Bool, to new: Bool) -> Bool {
        !old && new
    }

    /// What the seal shows: the full pop with its ring and haptic, or with Reduce Motion the finished seal at once
    /// (the haptic stays; the system turns it off when she asked).
    enum SealStyle: Equatable {
        case pop
        case settled
    }

    static func sealStyle(policy: MotionPolicy) -> SealStyle {
        policy.allowsMovement ? .pop : .settled
    }

    /// How long the check of the inline variant takes to draw: `Motion.Duration.draw`, and nothing with Reduce Motion.
    static func inlineDrawDuration(policy: MotionPolicy) -> Double {
        policy.allowsMovement ? Motion.Duration.draw : 0
    }
}
