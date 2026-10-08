//
//  MotionPolicy.swift
//  BelloHub
//

/// Decides what may move. Pure, so the decision matrix is tested without a view
/// (docs/09-MOTION.md sections 6 and 7).
struct MotionPolicy: Equatable {
    var reduceMotion = false
    var lowPowerMode = false
    /// UI tests launch with `-uiTesting`, which turns every animation off so assertions never race them.
    var uiTesting = false

    /// Offsets, scales, overshoot and arrival rises.
    var allowsMovement: Bool {
        !reduceMotion && !uiTesting
    }

    /// Loops: the hero glow and the unread pulse. Also off in Low Power Mode.
    var allowsAmbient: Bool {
        allowsMovement && !lowPowerMode
    }

    /// Reduce Motion keeps a short crossfade; UI tests keep nothing.
    var allowsFade: Bool {
        !uiTesting
    }
}
