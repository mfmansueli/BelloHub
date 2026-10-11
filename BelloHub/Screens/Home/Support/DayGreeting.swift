//
//  DayGreeting.swift
//  BelloHub
//

import Foundation

/// Which greeting the Home screen uses. Pure: the moment and the calendar (so the time zone) are parameters.
enum DayGreeting: Equatable, Sendable {
    case morning
    case afternoon
    case evening

    /// Morning until 11:59, afternoon until 17:59, evening after. The professional's own time zone decides, not the
    /// phone's, when the calendar carries it.
    static func at(_ now: Date, calendar: Calendar) -> DayGreeting {
        switch calendar.component(.hour, from: now) {
        case 5..<12: .morning
        case 12..<18: .afternoon
        default: .evening
        }
    }
}
