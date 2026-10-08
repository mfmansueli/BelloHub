//
//  DayOff.swift
//  BelloHub
//

import Foundation

/// Whole days closed, first to last inclusive, as the start of those days in the business time zone.
struct DayOff: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    var startDate: Date
    var endDate: Date
    var kind: DayOffKind
}
