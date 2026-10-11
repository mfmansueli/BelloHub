//
//  AvailabilityRule.swift
//  BelloHub
//

import Foundation

/// One stretch of the week she works. A weekday may have several (morning and evening). Minutes count from
/// local midnight in the business time zone.
struct AvailabilityRule: Hashable, Codable, Sendable {
    /// 1 is Sunday and 7 is Saturday, as in `Calendar`.
    var weekday: Int
    var startMinutes: Int
    var endMinutes: Int
}
