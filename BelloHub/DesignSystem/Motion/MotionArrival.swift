//
//  MotionArrival.swift
//  BelloHub
//

import SwiftUI

/// The decisions behind the arrival rise, as pure functions so the Reduce Motion behavior is tested
/// without a view (docs/09-MOTION.md sections 6 and 7).
enum MotionArrival {
    struct Frame: Equatable {
        let opacity: Double
        let offsetY: CGFloat
    }

    /// What a block looks like before it has appeared (`shown == false`) and after (`shown == true`).
    /// - Normal: starts transparent and 14 pt low, rises into place.
    /// - Reduce Motion: no travel at all, only a short fade.
    /// - UI testing: already in its final place, so assertions never wait.
    static func frame(shown: Bool, policy: MotionPolicy) -> Frame {
        if shown || !policy.allowsFade {
            return Frame(opacity: 1, offsetY: 0)
        }
        return Frame(opacity: 0, offsetY: policy.allowsMovement ? Motion.riseOffset : 0)
    }

    /// The animation that takes a block from its start frame to its final one, or nil when nothing animates.
    static func animation(index: Int, policy: MotionPolicy) -> Animation? {
        guard policy.allowsFade else { return nil }
        return policy.allowsMovement
            ? Motion.ease().delay(Motion.arrivalDelay(index: index))
            : .easeOut(duration: 0.2)
    }
}
