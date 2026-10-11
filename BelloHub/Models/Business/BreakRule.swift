//
//  BreakRule.swift
//  BelloHub
//

import Foundation

/// A recurring pause (lunch, coffee). With no weekday it applies every day.
struct BreakRule: Hashable, Codable, Sendable {
    var weekday: Int?
    var startMinutes: Int
    var endMinutes: Int
    var label: String
}
