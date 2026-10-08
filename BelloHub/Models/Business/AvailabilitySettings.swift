//
//  AvailabilitySettings.swift
//  BelloHub
//

import Foundation

/// Everything the free-slot calculation needs about when she can be booked (docs/05-DATA-MODEL.md).
struct AvailabilitySettings: Hashable, Codable, Sendable {
    var weekly: [AvailabilityRule]
    var breaks: [BreakRule]
    var daysOff: [DayOff]
    /// Time to reset the room and write notes between clients.
    var bufferMinutes: Int
    /// A client cannot book a start sooner than this from now.
    var minNoticeHours: Int
    /// Or further ahead than this.
    var maxDaysAhead: Int
    var timeZoneID: String

    var timeZone: TimeZone {
        TimeZone(identifier: timeZoneID) ?? .current
    }

    static let defaultBufferMinutes = 15
    static let defaultMinNoticeHours = 2
    static let defaultMaxDaysAhead = 60
}
