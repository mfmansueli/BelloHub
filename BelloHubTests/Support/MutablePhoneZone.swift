//
//  MutablePhoneZone.swift
//  BelloHubTests
//

import Foundation
import os

/// The iPhone's time zone as a test sets it, so a test can "travel" without touching the process's zone.
final class MutablePhoneZone: Sendable {
    private let current: OSAllocatedUnfairLock<String>

    init(_ identifier: String) {
        current = OSAllocatedUnfairLock(initialState: identifier)
    }

    var zone: TimeZone {
        TimeZone(identifier: current.withLock { $0 }) ?? .gmt
    }

    func set(_ identifier: String) {
        current.withLock { $0 = identifier }
    }
}
