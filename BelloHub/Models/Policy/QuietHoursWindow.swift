//
//  QuietHoursWindow.swift
//  BelloHub
//

import Foundation

/// A daily window when alerts are held. It may cross midnight (22:00 to 07:00). Minutes count from local midnight.
struct QuietHoursWindow: Hashable, Codable, Sendable {
    var fromMinutes: Int
    var untilMinutes: Int
}
