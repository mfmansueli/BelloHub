//
//  AvailabilityEditorMode.swift
//  BelloHub
//

import Foundation

/// Which sheet of the Availability screen is open and what it edits: the hours of a weekday, one break or one stretch
/// of days off. An `Identifiable` value, so `.sheet(item:)` builds a fresh sheet for each.
enum AvailabilityEditorMode: Identifiable, Equatable {
    case hours(weekday: Int)
    case addBreak
    case editBreak(index: Int, rule: BreakRule)
    case addDayOff
    case editDayOff(DayOff)

    var id: String {
        switch self {
        case .hours(let weekday): "hours.\(weekday)"
        case .addBreak: "break.new"
        case .editBreak(let index, _): "break.\(index)"
        case .addDayOff: "dayOff.new"
        case .editDayOff(let dayOff): "dayOff.\(dayOff.id.uuidString)"
        }
    }
}
