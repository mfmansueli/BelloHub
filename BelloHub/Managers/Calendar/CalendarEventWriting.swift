//
//  CalendarEventWriting.swift
//  BelloHub
//

import Foundation

/// The "Bello Hub" calendar on her iPhone behind a protocol, so the write-through is tested without EventKit.
protocol CalendarEventWriting: Sendable {
    /// The events of the "Bello Hub" calendar in `range`; empty when the calendar does not exist yet.
    func events(in range: DateInterval) async throws -> [CalendarEventRecord]
    /// Applies the changes in one commit, creating the "Bello Hub" calendar when needed.
    func apply(_ changes: CalendarEventChanges) async throws
    /// Removes the "Bello Hub" calendar and its events (she switched Apple Calendar off or signed out).
    func removeCalendar() async throws
}
