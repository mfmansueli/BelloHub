//
//  BeforeAfterSnap.swift
//  BelloHub
//

import Foundation

/// Where the before/after handle comes to rest when she lets go of it. It follows the finger exactly while she drags;
/// on release it settles on the places worth showing: all "before", all "after", or the half where both are equal,
/// when it is already close to one of them. Anywhere else it stays where she left it. Pure.
enum BeforeAfterSnap {
    /// How close to an end the handle has to be to settle on it.
    static let edgeReach = 0.06
    /// How close to the middle.
    static let middleReach = 0.04

    static func settled(_ fraction: Double) -> Double {
        let value = min(max(fraction, 0), 1)
        if value <= edgeReach { return 0 }
        if value >= 1 - edgeReach { return 1 }
        if abs(value - 0.5) <= middleReach { return 0.5 }
        return value
    }
}
