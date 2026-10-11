//
//  CalendarEventRecord.swift
//  BelloHub
//

import Foundation

/// An event that is already in her "Bello Hub" calendar, as the calendar reports it. `appointmentID` is read back from
/// the event's address (`CalendarEventPlanner.url(for:)`); nil for an event she added to that calendar by hand.
struct CalendarEventRecord: Hashable, Sendable {
    let identifier: String
    let appointmentID: UUID?
    let title: String
    let start: Date
    let end: Date
}
