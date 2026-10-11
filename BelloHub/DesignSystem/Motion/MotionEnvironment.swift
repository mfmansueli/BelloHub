//
//  MotionEnvironment.swift
//  BelloHub
//

import SwiftUI

private struct MotionDisabledKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    /// Set once at the root from the DEBUG `-uiTesting` launch argument, because the design system
    /// must not read launch options (it depends on nothing above it).
    var isMotionDisabled: Bool {
        get { self[MotionDisabledKey.self] }
        set { self[MotionDisabledKey.self] = newValue }
    }

    /// The effective policy for the view: system settings plus the root's testing switch.
    var motionPolicy: MotionPolicy {
        MotionPolicy(
            reduceMotion: accessibilityReduceMotion,
            lowPowerMode: ProcessInfo.processInfo.isLowPowerModeEnabled,
            uiTesting: isMotionDisabled
        )
    }
}
