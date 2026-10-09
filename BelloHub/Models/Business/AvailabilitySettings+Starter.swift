//
//  AvailabilitySettings+Starter.swift
//  BelloHub
//

import Foundation

extension AvailabilitySettings {
    /// Where a professional starts before she edits anything: Monday to Friday, 09:00 to 18:00, with the standard
    /// buffer, notice and booking window. A suggestion, not a promise: the screen says so until something is saved.
    static func starter(timeZoneID: String) -> AvailabilitySettings {
        AvailabilitySettings(
            weekly: (2...6).map { AvailabilityRule(weekday: $0, startMinutes: 9 * 60, endMinutes: 18 * 60) },
            breaks: [],
            daysOff: [],
            bufferMinutes: defaultBufferMinutes,
            minNoticeHours: defaultMinNoticeHours,
            maxDaysAhead: defaultMaxDaysAhead,
            timeZoneID: timeZoneID
        )
    }
}
