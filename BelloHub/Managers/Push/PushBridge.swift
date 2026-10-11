//
//  PushBridge.swift
//  BelloHub
//

import Foundation

/// The one place `AppDelegate` (outside the view tree) finds the push provider. A singleton only for that reason
/// (CLAUDE.md section 2); `AppDependencies` sets it once at launch.
@MainActor
final class PushBridge {
    static let shared = PushBridge()

    var provider: (any PushTokenProviding)?

    private init() {}
}
