//
//  LockPolicy.swift
//  BelloHub
//

import Foundation

/// When the app asks for Face ID or the passcode again. Pure: the clock is a parameter (CLAUDE.md section 2).
enum LockPolicy {
    /// Seconds in the background the professional can pick from. 0 locks the moment she leaves.
    static let graceOptions = [0, 30, 60, 300, 900]
    static let defaultGraceSeconds = 60

    /// Whether to lock when the app comes back to the foreground.
    /// - Parameters:
    ///   - leftAt: when the app went to the background, or nil if it never did in this launch.
    static func shouldLock(isEnabled: Bool, leftAt: Date?, now: Date, graceSeconds: Int) -> Bool {
        guard isEnabled else { return false }
        guard let leftAt else { return true }
        let away = now.timeIntervalSince(leftAt)
        // A clock that moved backwards must not keep the app open: lock.
        return away < 0 || away >= TimeInterval(graceSeconds)
    }

    /// A stored value that is not one of the options (an old build, a hand-edited default) becomes the default.
    static func normalizedGrace(_ stored: Int?) -> Int {
        guard let stored, graceOptions.contains(stored) else { return defaultGraceSeconds }
        return stored
    }
}
